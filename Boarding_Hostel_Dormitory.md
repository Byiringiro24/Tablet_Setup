TECHNICAL FUNCTIONAL REQUIREMENTS
Boarding / Hostel Biometric Attendance Module

1. Purpose
This document defines the required functionality and workflow for daily boarding/hostel attendance using the biometric devices. this document focuses on the attendance business logic, portal workflow, alerts, notifications, reporting, and role-based access.
2. Hostel / Boarding Structure
The system should support multiple hostels and multiple blocks within each hostel. Each boarding student should be associated with the relevant Hostel, Block, and Room where applicable.
•	School → Hostel/Boarding → Block → Room → Student
•	Each biometric device should be mapped to its corresponding hostel/block location. If required by school
•	The device location should allow the system to determine which block the attendance event belongs to.
•	Users responsible for individual blocks should only see students assigned to their respective blocks.
3. Core Attendance Concept
The biometric device is primarily used to capture the student's attendance event. The School Management System is responsible for interpreting the attendance event, checking leave/authorization status, generating missing-attendance alerts, sending notifications, and producing reports.
A biometric attendance record should contain, at minimum:
•	Student/User ID
•	Date
•	Time
•	Device ID / Block
•	Attendance event/status
4. Daily Boarding Attendance Window
The system should have a configurable daily boarding attendance window. Example: 7:00 PM–9:00 PM. The actual time should be configurable by an authorized administrator rather than hard-coded.
•	Attendance recorded within the defined window is treated as Present.
•	Attendance recorded after the defined expected time may be classified as Late, according to school policy.
•	Once the attendance window closes, the system should perform an automated attendance reconciliation.
•	The system should not immediately classify a student as unauthorized absent without checking approved leave and other authorized statuses.

5. Daily Attendance Reconciliation
At the end of each attendance window, the system should automatically:
1.	Retrieve the list of all boarding students expected to attend that day.
2.	Match each student against the biometric attendance records.
3.	Identify students who are Present.
4.	Identify students who are Late, where applicable.
5.	Check students with no attendance record against approved leave.
6.	Exclude students with valid approved leave from unauthorized-missing notifications.
7.	Mark remaining students with no attendance as Missing Attendance.
8.	Generate alerts and notifications according to the user's role and the configured communication rules.
9.	Generate the daily boarding attendance report.
6. Leave Validation Logic
The missing-attendance workflow must include an automatic leave check:
Attendance	Approved Leave	System Action
Present		Record Present; no absence alert.
Missing	Yes	Record as On Approved Leave; do not send unauthorized absence SMS/app alert. But notified parents as your kid missed attendance because he/she is on leave as per school record.
Missing	No	Record as Missing Attendance; trigger configured alerts and parent notifications.
7. Role-Based Visibility and Alerts
Notifications and portal visibility should be role-based. A user responsible for a particular block must not receive unrelated blocks' student-level alerts. Future Expansion.
Role	Required Visibility	Required Alert/Report
Block Warden / Block Officer	Students assigned to that block	Daily student-level attendance status and missing-attendance alerts for that block.
Boarding Officer	All boarding students / assigned boarding scope	Daily overall report and prominent missing-attendance alert.
Boarding Head	All boarding students	Overall boarding report, block-wise summary, and missing-attendance details.
School Admin	Full school scope	Complete daily boarding attendance report and exception summary.
8. Boarding Officer / Boarding Head Dashboard
The dashboard should provide a clear daily summary, including:
•	Total Boarding Students
•	Present
•	Late
•	On Approved Leave
•	Missing Attendance
•	Attendance Percentage
•	Block-wise attendance summary
Missing Attendance should be displayed as a prominent red alert. Example: “12 Students have missing boarding attendance today.” Clicking the alert should open the student list.
9. Missing Attendance Student List
The missing-attendance list should include, where applicable:
•	Student Name
•	Student ID
•	Class/Grade
•	Hostel
•	Block
•	Room
•	Attendance Status
•	Leave/Authorization Status
•	Relevant action/status history
10. Parent Notifications
If a student has no biometric attendance record and is not on approved leave, the system should send a parent notification through the configured SMS service and the Parents Application.
Notification wording should clearly state that the student's boarding attendance has not been recorded and advise the parent to contact the school if the absence is not authorized.
11. Parents Application
Parents should be able to view the student's boarding attendance history, including:
•	Today's attendance status
•	Attendance/check-in time
•	Recent attendance history
•	Present/Late/Missing/Approved Leave status
•	Attendance percentage, where configured
For the current day, the parent should see a clear status such as Present, Late, On Approved Leave, or Missing Attendance.
12. Daily Boarding Attendance Report
A daily report should be automatically available to authorized portal users. It should include:
•	Total boarding students
•	Present count
•	Late count
•	Approved Leave count
•	Missing Attendance count
•	Attendance percentage
•	Block-wise summary
•	Detailed list of missing students
Example summary:
•	Block A: 150 students | 145 Present | 3 Late | 2 Missing
•	Block B: 140 students | 131 Present | 4 Late | 3 Missing
13. Manual Attendance Correction
Because biometric attendance can occasionally be affected by operational issues, an authorized user should be able to correct or add an attendance record manually.
•	Only authorized roles may perform corrections.
•	A reason must be entered for every manual change.
•	The system must record who made the change and when.
•	The original attendance information should be retained in the audit history where technically possible.
•	Manual changes must be distinguishable from biometric-generated records.
14. Audit Trail
Attendance status changes, manual corrections, leave-related overrides, and other attendance exceptions should be recorded in an audit trail. The audit trail should include the action, user, date/time, original status where applicable, and updated status.
15. Device Connectivity / Synchronization Status

•	Device online/offline status.
•	Last successful synchronization time.
•	Last received attendance event.
•	Un-synchronized or delayed attendance records,
•	Device/block association.
If a device stores attendance locally while temporarily offline, the system should accept synchronized records once the device reconnects and should avoid creating duplicate attendance records.
16. Duplicate Attendance Handling
The system should define how multiple biometric events from the same student during the attendance window are handled. The recommended approach is to retain the raw events but use the last valid event  as the student's daily attendance/check-in status.
17. Automated Daily Workflow
Recommended end-to-end workflow:
10.	Student reaches the assigned hostel/block and records biometric attendance.
11.	Device sends/stores the attendance event through the existing integration.
12.	System associates the event with the student and block.
13.	Attendance window closes at the configured time.
14.	System checks every expected boarding student.
15.	Students with valid attendance are marked Present/Late according to the rules.
16.	Students without attendance are checked against approved leave.
17.	Students on approved leave are excluded from unauthorized absence alerts.
18.	Students with neither attendance nor approved leave are marked Missing Attendance.
19.	Relevant block staff receive block-level alerts.
20.	Boarding Officer and Boarding Head receive the appropriate daily report and red missing-attendance alert.
21.	Parents of unauthorized missing students receive SMS and Parents App notification.
22.	Daily attendance report remains available in the portal for authorized users.
18. Recommended Statuses
Status	Meaning
Present	Valid attendance recorded within the configured attendance rules.
Late	Attendance recorded after the configured expected time.
Missing Attendance	No valid attendance record and no approved leave/authorized status.
On Approved Leave	Student has a valid approved leave covering the attendance period.
Manual/Adjusted	Attendance status was created or corrected by an authorized user.
19. Functional Requirements Summary
•	The system must support hostel/block-based student assignment.
•	The system must associate biometric attendance with the correct student and block.
•	The attendance window must be configurable.
•	The system must automatically reconcile attendance at the end of the attendance window.
•	The system must check approved leave before generating missing-attendance notifications.
•	The system must generate block-level and overall alerts according to user permissions.
•	The Boarding Officer/Head dashboard must clearly highlight missing attendance.
•	Parents must receive SMS and Parents App notifications for unauthorized missing attendance.
•	Authorized users must be able to view daily and historical attendance reports.
•	Authorized users must be able to make controlled manual corrections with an audit trail.
•	The system should detect or expose synchronization/device issues.
•	Duplicate attendance events must be handled consistently.
•	All student-level information must follow role-based access permissions.
20. Scope Note
This specification intentionally focuses on the boarding/hostel attendance functionality. Existing biometric devices, their device details, and available APIs/integration mechanisms are assumed to be already available to the development team. Existing approved outing functionality is also outside the scope of this attendance module and should continue to be respected when determining attendance/absence status.
