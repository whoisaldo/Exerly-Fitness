# Exerly help

Prepared for publication on Sideband after release review. Contact
hello@sideband.studio. Never send your password, access tokens or complete
health records in a support message.

## Sign in

Use the same sign-in method you used to create your account. To add Sign in
with Apple to an existing password account, sign in first, then open Profile,
Account settings. An Apple-only account must keep Apple connected so you can
continue signing in.

The current internal TestFlight build connects to private staging on devbox1.
Turn on Tailscale before signing in or syncing. It uses a separate account
service from the public website. Internal test credentials are provided
privately; they are not a public demo account.

## Log food and training

The diary shows the selected day. Use the plus button or a meal's Add food
action to search, scan a barcode, choose a saved food or enter a custom label.
Blank nutrients mean the label does not report them. They are not treated as
known zeroes.

Training opens the next planned day, or offers a new workout. Review a planned
workout before starting. Enter a set, mark it complete, and finish the workout
when you are done. Saved sets remain available after closing and reopening
the app.

## Units and appearance

New accounts use nutritional Calories, pounds, feet and inches, and fluid ounces
for water. Macros use grams. Change an explicit metric or U.S. preference in
Profile and Preferences. Appearance choices are in Profile. Exerly also follows
the text size chosen in your device's accessibility settings.

## Offline records and conflicts

Supported logs are saved on your device while you are offline and sync when
you reconnect. A change that conflicts with another device needs review. Read
both versions before choosing which one to keep. Keep Exerly installed while
you have changes waiting to sync.

If data does not appear after reconnecting, open Profile, Sync and retry. Check
for a saved-change review or an account error. Signing out and deleting the app
are not troubleshooting steps for unsynced records.

## Apple Health and progress photos

Profile, Apple Health controls whether Exerly reads today's steps and active
Calories. Missing data can mean there are no samples or that read access is
off. Check permissions in the Health app. Exerly does not infer which read
permissions you declined.

Progress, Photos stores selected photos on this device. Choose Compare and
select two photos to compare them. Account JSON exports do not include progress
photos, and photos are not uploaded to Exerly's account service.

## Export or delete your account

Open Profile, Account settings, Export data. Share account export prepares a
JSON file of your records. Offline, Share device export includes only records
available on this device.

Delete account shows a confirmation before deleting. Apple-linked accounts may
need to authorize the deletion through Apple. A failed request keeps the account
available so you can retry. If the service confirms deletion but local cleanup
fails, keep the app installed and use the cleanup retry.

Account deletion does not remove data from Apple Health or files and copies
you previously exported or shared.

## Report a problem

For TestFlight, use Apple's Send Beta Feedback. For support, include the Exerly
version and build, device model, iOS version, the screen involved, and the steps
that led to the problem. Use made-up entries if you can reproduce it that way.
Remove personal information from any screenshot you choose to share.
