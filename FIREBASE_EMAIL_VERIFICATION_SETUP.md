# Firebase Email Verification and Account Services

EN English | [TR Türkçe](FIREBASE_EMAIL_VERIFICATION_SETUP_TR.md)

This document explains Winner Spin's active Firebase email-verification flow, Firestore verified-state synchronization, and the client-side account deletion flow.

Use your own Firebase project ID in every command below.

---

## 1. Email Verification

Winner Spin uses Firebase Authentication's built-in email verification link:

1. Registration creates and signs in the Firebase user.
2. The application requests a verification email.
3. The user opens Firebase's **Verify Email** link.
4. When the application returns to the foreground, it reloads the Firebase user.
5. The authentication gate admits only users whose Firebase token reports a verified email.
6. The verification screen limits resend attempts to one every 60 seconds; Firebase also applies its own anti-abuse limits.

This flow does not require Cloud Functions, the Trigger Email extension, or a custom SMTP server.

### Firebase Console Configuration

1. Open your project in Firebase Console.
2. Go to **Authentication > Sign-in method**.
3. Enable **Email/Password**.
4. Go to **Authentication > Templates > Email address verification**.
5. Keep the template enabled and customize its sender name, subject, and body if required.

---

## 2. Firestore Verified-State Synchronization

After Firebase Authentication reports a verified user, the application makes a best-effort update to the users/{uid}.emailVerified field.

Deploy the repository's Firestore rules:

~~~sh
firebase deploy --only firestore:rules --project=YOUR_PROJECT_ID
~~~

The rule permits the signed-in owner to set emailVerified to true only when the Firebase Authentication token already contains the verified-email claim.

Firebase Authentication link verification still works if these Firestore rules are not deployed. Only synchronization of the verified state into the Firestore profile may fail.

---

## 3. Full Account Deletion

The full account-deletion action is available from both the profile and the unverified-email screen and runs entirely on the client. After reauthenticating the player it archives any disclaimer acceptance, deletes `users/{uid}` and the legacy `emailVerifications/{uid}` document in one batch, tombstones and erases the user's local files, and finally removes the Firebase Authentication user. Keeping local cleanup before Authentication deletion ensures that an interrupted cleanup leaves an authenticated account that can safely retry. If the last step fails, the post-login profile gate keeps the incomplete account out of the game and offers a safe retry or sign-out path.

The order cannot be reversed. Firestore rules only let the owner delete their own profile, so the Authentication user has to survive until the document is gone.

This requires no Cloud Functions and no billing account. What it does require is the Firestore rules being deployed. Destructive writes require the owner token's `auth_time` to be no more than five minutes old (and not in the future); reauthentication immediately before deletion supplies that fresh token.

~~~sh
firebase deploy --only firestore:rules --project=YOUR_PROJECT_ID
~~~

The archived acceptance record is create-once and is not readable from any client. It survives the account so the 18+ confirmation can still be evidenced afterwards.

---

## 4. Security Notes

- Treat service-account files, private keys, access tokens, passwords, and OAuth client secrets as confidential.
- Do not commit credentials to the repository or include them in documentation.
- Firebase project IDs and client configuration values are identifiers, not authorization controls.
- Protect data and callable operations with Firebase Authentication, authorization checks, and Firestore Security Rules.
- Deploy only the Firebase services required by the active application flow.
