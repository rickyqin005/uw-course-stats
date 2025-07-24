

const axios = require('axios');
const cheerio = require("cheerio");
const fs = require('fs');
const path = require('path');

import { createPGClient, arrsFormat, formatSQL, log } from './utility';
const { term, subjects, daysOfWeekAbbrev } = require('./consts.json');

const REFRESH_INTERVAL = 1800000;
const RETRY_INTERVAL = 30000;

// refresh every 30 minutes
export default async function refreshData() {
    refresh(0, [], [], [], []);
}

function refresh(subjectIndex: number,
    courses: any[][], sections: any[][], enrollment: any[][], timeslots: any[][]) {
    
    try {
        if(subjectIndex < subjects.length) {
            fetchSubject(subjects[subjectIndex], courses, sections, enrollment, timeslots)
            .then(() =>
                setTimeout(() => refresh(subjectIndex+1, courses, sections, enrollment, timeslots), 0)
            );
        } else {
            // update DB all at once at the end
            updateDB(courses, sections, enrollment, timeslots)
            .then(() =>
                setTimeout(() => refresh(0, [], [], [], []), REFRESH_INTERVAL)
            );
        }
    } catch(error) {
        console.log(error);
        setTimeout(() => refresh(0, [], [], [], []), RETRY_INTERVAL);
    }
}

async function fetchSubject(subject: string, courses: any[][], sections: any[][], enrollment: any[][], timeslots: any[][]) {
    console.time(subject);

    const webpage = await axios.get(`https://classes.uwaterloo.ca/cgi-bin/cgiwrap/infocour/salook.pl?level=under&sess=${term}&subject=${subject}`);
    const $ = cheerio.load(webpage.data);

    $('body > main > p > table > tbody > tr')
    .filter((idx, element) => element.children.length == 8 || element.children.length == 2)
    .each((idx, element) => {
        
        // course general info
        if(element.children.length == 8) {
            courses.push([
                $(element).children(':nth-child(1)').text().trim(),// subject
                $(element).children(':nth-child(2)').text().trim(),// code
                Number($(element).children(':nth-child(3)').text()),// units
                $(element).children(':nth-child(4)').text().trim()// title
            ]);
        } else {
            // course sections
            $(element).find('table > tbody > tr:not(:first-child)')
            .each((idx, element) => {

                // skip cancelled sections
                const lastTxt = $(element).children(':last-child').text().trim();
                if(lastTxt == 'Cancelled Section' || lastTxt == 'Closed Section') {
                    while(timeslots.length > 0 && timeslots.at(-1)[0] == sections.at(-1)[0]) {
                        timeslots.pop();
                    }
                    enrollment.pop();
                    sections.pop(); return;
                }

                const code = parseInt($(element).children(':first-child').text());
                const dateArr: string[] = $(element).children(':nth-last-child(2)').html().split('<br>');
                const timeStr = (/^\d{2}:\d{2}-\d{2}:\d{2}\D+$/.test(dateArr[0]) ? dateArr[0] : '');
                const dateStr = (/^\d{2}\/\d{2}-\d{2}\/\d{2}$/.test(dateArr.at(-1)) ? dateArr.at(-1) : '');

                let startTimeHours = 0, startTimeMinutes = 0;
                let endTimeHours = 0, endTimeMinutes = 0;
                let startTimeStr: string | undefined, endTimeStr: string | undefined;
                let daysOfWeek = 0;
                if(timeStr != '') {
                    startTimeHours = parseInt(timeStr.slice(0,2));
                    startTimeMinutes = parseInt(timeStr.slice(3,5));
                    endTimeHours = parseInt(timeStr.slice(6,8));
                    endTimeMinutes = parseInt(timeStr.slice(9,11));
                    if(startTimeHours < 8 || (startTimeHours == 8 && startTimeMinutes < 30)) {
                        startTimeHours += 12;
                        endTimeHours += 12;
                    }
                    if(startTimeHours*60+startTimeMinutes >= endTimeHours*60+endTimeMinutes) {
                        endTimeHours += 12;
                    }
                    startTimeStr = `${startTimeHours}:${startTimeMinutes.toString().padStart(2, '0')}`;
                    endTimeStr = `${endTimeHours}:${endTimeMinutes.toString().padStart(2, '0')}`;

                    // loop from monday to sunday, check for edge case 'T' and 'Th'
                    for(let j = 11, k = 0, pow = 1; k < daysOfWeekAbbrev.length && j < timeStr.length; k++, pow *= 2) {
                        if(timeStr.slice(j,j+daysOfWeekAbbrev[k].length) == daysOfWeekAbbrev[k] && 
                            (daysOfWeekAbbrev[k] != 'T' || !(j+1 < timeStr.length && timeStr.charAt(j+1) == 'h'))) {
                            daysOfWeek += pow;
                            j += daysOfWeekAbbrev[k].length;
                        }
                    }
                }
                let startDate: Date | null = null;
                let endDate: Date | null = null;
                if(dateStr != '') {
                    startDate = new Date(Date.UTC(2024, parseInt(dateStr.slice(0,2))-1, parseInt(dateStr.slice(3,5))));
                    endDate = new Date(Date.UTC(2024, parseInt(dateStr.slice(6,8))-1, parseInt(dateStr.slice(9,11))));
                }

                if(!isNaN(code)) {
                    console.assert(element.children.length == 12);
                    enrollment.push([
                        code,                                                                       // section_id
                        parseInt($(element).children(':nth-child(8)').text()) || 0                  // enroll_total
                    ])
                    sections.push([
                        code,                                                                       // section_id
                        courses.at(-1)[0],                                               // course_subject
                        courses.at(-1)[1],                                               // course_code
                        $(element).children(':nth-child(2)').text().trim(),                         // component
                        $(element).children(':nth-child(3)').text().trim().replace(/[\s]+/, ' '),   // location
                        parseInt($(element).children(':nth-child(7)').text()) || 0,                 // enroll_cap
                    ]);
                }

                if(timeStr != '' || dateStr != '') {
                    timeslots.push([
                        sections.at(-1)[0],// section_id
                        startTimeStr,// start_time
                        endTimeStr,// end_time
                        daysOfWeek,// days_of_week
                        startDate?.toISOString().slice(0,10),// start_date
                        endDate?.toISOString().slice(0,10)// end_date
                    ]);
                }
            });
        }
    });

    console.timeEnd(subject);
}

async function updateDB(courses: any[][], sections: any[][], enrollment: any[][], timeslots: any[][]) {
    console.time('updateDB');
    const sql = formatSQL('./postgres/refresh.sql',
        arrsFormat(courses), arrsFormat(sections), arrsFormat(enrollment), arrsFormat(timeslots));
    fs.writeFile(path.resolve(__dirname, "./sql.sql"), sql, () => {});

    const pgClient = createPGClient();
    await pgClient.connect();
    await pgClient.query(sql);
    await pgClient.end();
    console.timeEnd('updateDB');
}
