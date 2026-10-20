# Shai Hills Farm OS

Sprint 1 of the livestock records app for Shai Hills Farm in Shai Hills, Ghana. The farm is 20 acres in total, across two sites 7 km apart. The herd in this sprint is pigs, cattle, goats, and poultry. Money, when later sprints record it, is in Ghana cedis.

This build covers sign-in, the herd dashboard, and the animal register. Breeding, health, feed, mortality, sales, reporting, dairy KPIs, and offline sync are later sprints and are not in the app yet.

The stack is Flutter, with Supabase Auth and PostgreSQL when you connect a project. Android is the primary target. Web is enabled so the same app can be reviewed in a browser.

## Run locally with on-device records

No Supabase project and no keys are required. Leave `SUPABASE_URL` and `SUPABASE_ANON_KEY` unset.

```bash
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 47231
```

Then open the printed URL. On a phone or emulator:

```bash
flutter run -d android
```

On the sign-in screen, choose **Need an account? Create one**. Use any email address and a password of at least 8 characters. The account and the herd are stored only on this device. A second account on the same device has its own register.

The dashboard counts animals marked **On farm**. Sold and dead animals stay on the register and are left out of those counts.

## Connect a Supabase project

Supabase is optional. The app uses it only when both of these are set:

| Variable | Purpose |
| --- | --- |
| `SUPABASE_URL` | Project URL, such as `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | The project’s public anon key (also called the publishable key) |

Do not commit either value. `env.json` is gitignored.

1. Create a Supabase project and turn on the Email provider.
2. Run [`supabase/migrations/20261020140000_animals.sql`](supabase/migrations/20261020140000_animals.sql) in the SQL editor. That creates the `animals` table and row-level security so each account sees only its own rows.
3. For a local trial, turn off **Confirm email** if you want the app to open the herd immediately after **Create account**. If confirmation stays on, the app asks you to confirm, then sign in.
4. Copy the example file and fill in the two values from the Supabase API settings:

```bash
cp env.example.json env.json
flutter run -d chrome --dart-define-from-file=env.json
```

The same file works for Android:

```bash
flutter run -d android --dart-define-from-file=env.json
```

You can pass the values without a file:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

If only one of the two values is set, or Supabase fails to start, the app stays on the on-device records and says so on the sign-in screen.

Reads and writes go through one animal-register interface. Sprint 1 implements Supabase and the on-device store. A later offline sync can sit behind that same interface.

## Tests

```bash
flutter test
```
