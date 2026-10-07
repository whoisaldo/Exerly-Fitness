# Exerly privacy notice

Draft for Ali's review, 2026-10-07. Not published. Resolve the decisions in
[privacy review](privacy-review.md) before using this as a public policy.

Exerly is a training and nutrition app from Sideband. Contact
hello@sideband.studio with questions about your data.

## Your account and records

Exerly stores the information you provide to run your account: your name, email,
sign-in method and profile preferences. If you use Sign in with Apple, Apple
may provide a private relay email address. Passwords are stored as hashes.

Your food logs, body measurements, activity, sleep, workouts, programs, goals,
notes and agent proposals can sync to your Exerly account. Saved copies let
you use supported logging features offline. Exerly uses these records to show
your history, calculate training and nutrition information, and carry out
changes you request. Some records include an edit or decision history.

## Apple Health and photos

Apple Health access is optional. The current Health screen asks to read steps
and active Calories so it can show today's activity. You choose the data types
in Apple's permission sheet. Those readings are displayed on your device;
this screen does not upload them to your Exerly account or write Health records.
Turning reading off in Exerly stops this screen from reading. Manage Apple's
permissions in the Health app.

Progress photos selected in Exerly are stored in the app on your device. Exerly
does not upload them to its account service. Device backups and copies you
share are controlled by your device settings and the services you choose.
Account JSON exports do not include these photos.

## Food search and connected agents

Food searches and barcodes are sent through Exerly's service to the food
provider named in the result. The current native search uses Open Food Facts.
The provider receives the search text or barcode, not your Exerly food diary.
Avoid including personal information in a food search.

Connecting an agent is optional. An agent can access only the permissions you
grant to its token. Proposed changes wait for your review; direct write access
requires a separate choice. Revoke a token in Profile, Connected agents. The
agent or service you connect may retain information it already received under
its own policies. Revoking access prevents future access with that token.

Manual logging works without an AI service. This build does not require sending
your logs to a hosted model to use its main screens.

## Your choices

Use Profile, Account settings, Export account data to save an account export.
An offline device export contains the records available on that device. Files
you export or share become your responsibility to store securely.

You can initiate account deletion in Profile, Account settings, Delete account.
The app explains the confirmation and any sign-in check. Deletion removes the
account's records from the active service and starts cleanup on this device.
Keep the app installed if it asks to retry local cleanup. Other devices may
retain offline copies until they reconnect. Deleting Exerly does not delete
records from Apple Health or copies held by services you connected.

Exerly's current app has no advertising SDK or third-party analytics SDK and
does not track you across other companies' apps or websites. During TestFlight,
Apple handles beta feedback and crash reports through its testing service.

The published notice will identify the production hosting providers, retention
periods, backup deletion schedule, applicable privacy rights and effective date
after those operational and legal decisions are confirmed.
