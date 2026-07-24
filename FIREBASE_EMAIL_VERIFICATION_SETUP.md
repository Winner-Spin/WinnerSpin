# Firebase Email Verification and Account Services

EN English | [TR Türkçe](FIREBASE_EMAIL_VERIFICATION_SETUP_TR.md)

This document explains Winner Spin's active Firebase email-verification flow, Firestore verified-state synchronization, and the Cloud Function required for full account deletion.

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

The profile's full account-deletion action calls the deleteAccount callable Cloud Function. Deploy only this function:

~~~sh
firebase deploy --only functions:deleteAccount --project=YOUR_PROJECT_ID
~~~

Deploying Cloud Functions requires the Firebase project to meet the applicable billing requirements.

Email verification does not depend on this function; full account deletion does.

---

## 4. Security Notes

- Treat service-account files, private keys, access tokens, passwords, and OAuth client secrets as confidential.
- Do not commit credentials to the repository or include them in documentation.
- Firebase project IDs and client configuration values are identifiers, not authorization controls.
- Protect data and callable operations with Firebase Authentication, authorization checks, and Firestore Security Rules.
- Deploy only the Firebase services required by the active application flow.
