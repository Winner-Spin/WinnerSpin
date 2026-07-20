# Firebase email verification setup (Spark plan)

WinnerSpin uses Firebase Authentication's built-in email verification link.
This flow works on the no-cost Spark plan and does not require Cloud Functions,
the Trigger Email extension, or a custom SMTP server.

## One-time Firebase console setup

1. Open Firebase Console for project `winnerspin-fc03f`.
2. Go to **Authentication > Sign-in method**.
3. Enable **Email/Password**.
4. Go to **Authentication > Templates > Email address verification**.
5. Keep the template enabled and customize its sender name, subject, and body
   if desired.

Deploy the included Firestore rules (this does not require Blaze):

```sh
firebase deploy --only firestore:rules --project=winnerspin-fc03f
```

The rule only lets the signed-in owner set `emailVerified` to `true` when the
Firebase Authentication token already contains a verified-email claim.

## App flow

- Registration signs the new user in and sends `sendEmailVerification()`.
- The user opens the email and taps Firebase's **Verify Email** link.
- When WinnerSpin returns to the foreground, it reloads the Firebase user.
- Verified users continue to the game; unverified users remain on the
  verification screen.
- Resending is disabled for 60 seconds in the UI. Firebase also applies its own
  anti-abuse limits.

The previous custom six-digit-code flow and its automatic one-hour account
cleanup are not part of the Spark-compatible verification flow.
