# Katamansu Spice Farm

Katamansu Spice Farm is the livestock app for the commercial farm at Shai Hills, Ghana. The herd on the ground is about 1,000 pigs, 100 cattle, and 20 goats. Poultry houses can hold 1,000 birds, or 2,000 if every pen is used. The two yards, Piggery Site and Cattle/Poultry Site, are about 7 km apart. The land is about 20 acres. Money is in Ghana cedis.

The app is a website that also installs on a phone or tablet. The same screens run on iPhone, iPad, Android phones, and Android tablets. On a wide screen the menu moves to the side. On a phone it stays along the bottom.

People sign in with a phone number. The app sends a 6-digit code by text. There is no password.

It is meant for the people who work the farm. There are five pages. Workers do not see Money.

- **Home** shows pigs, cattle, goats, and poultry. Chips open Piggery, Cattle, Birds, Jobs, and Feed. Jobs are green, amber, or red. Feed shows kilos still on hand. Admins and managers also see revenue. Tap a revenue bar to see the sales behind it.
- **Today** is the big-button page. Everyone can record a birth, a death, or feed used. Managers can also record feed bought, a service, a weigh-in, or a vaccine.
- **Money** is for admins and managers. **Expenses** records vet, labour, transport, fuel, repairs, feed, or other costs, and which site it belongs to. Feed asks for kilos, vet asks for the animal, labour asks for people and days, fuel asks for litres, and transport or repairs asks what it was. Take a photo of the receipt or choose one. With a Gemini key the amount and supplier are filled in to check. **Sales** shows what came in this month, by enterprise, and records a new sale.
- **Animals** is the register. Each animal has a tag, a species, female or male, a breed where it matters, a site, and a status: on farm, sold, dead, or culled.
- **Book** is the short notebook for health, feed, breeding, milk, a sale, or a death.

A sale or a death updates that animal, so it drops out of the herd counts and stays on the register. Sold, dead, and culled animals are left out of the counts on Home.

Everyone on the farm sees the same herd. The practice account is the **admin**. A new number joins as a **worker** and cannot see sales or feed cost. The admin opens **People** and can make that person a manager.

Births, deaths, feed, expenses, and sales are saved on the phone first and sent on when the connection returns. The Android app works with no signal.

The shape of the system, the database, and the KPI rules are in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Try the practice account

No Supabase project and no keys are required. Leave `SUPABASE_URL` and `SUPABASE_ANON_KEY` unset. Records stay in the browser on that phone or tablet.

```bash
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 47231
```

Open the printed URL. On the sign-in screen:

| | |
| --- | --- |
| Phone | `024 412 0008` |
| Code | `123456` |

Tap **Send code**, enter `123456`, then tap **Sign in**. That practice account is already on the farm. The first time the on-device register is empty, a sample herd is added so Home and Money have something to show: 1,000 pigs (380 sows, 20 boars, 600 growers), 100 cattle, and 20 goats, plus births, sales, and six months of expenses. Poultry housing is recorded as capacity. Your own records stay once you add them. A new person taps **I am new here**, enters their phone number, and uses the code shown on the screen. Until a text service is connected, the code is shown there so the farm can still sign in. It works for 5 minutes.

A second phone number on the same device sees the same animals and the same book. A new number is a worker.

To open it like an app:

- **iPhone or iPad:** in Safari, tap Share, then **Add to Home Screen**.
- **Android:** in Chrome, open the browser menu and choose **Install app** or **Add to Home screen**.

The page can be rotated. A tablet in landscape gets a side menu and a single row of herd counts.

Build the installable site (the release build includes the service worker that lets the home-screen icon open the app):

```bash
flutter build web
```

Serve the `build/web` folder over HTTPS. Opening that site and using **Add to Home Screen** or **Install app** keeps a copy of the app on the device. On-device records still live in that browser profile. Clearing the browser data removes them.

The phone people carry into the pens is the Android app. It keeps working when there is no internet. Install it with a USB cable:

```bash
flutter build apk
flutter install
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. Copy that file to each phone and open it. The first time, Android asks you to allow install from that source.

```bash
flutter run -d android
flutter run -d ios
```

## Connect a Supabase project

Supabase is optional. Use it when the same herd should be available from more than one device, and when the code should arrive as a real text message. The app uses it only when both of these are set:

| Variable | Purpose |
| --- | --- |
| `SUPABASE_URL` | Project URL, such as `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | The project’s public anon key (also called the publishable key) |

Do not commit either value. `env.json` is gitignored.

1. Create a Supabase project and turn on the Phone provider. Connect an SMS provider, such as Twilio, so the code can be texted.
2. Run these files in the SQL editor, in order:
   - [`supabase/migrations/20261020140000_animals.sql`](supabase/migrations/20261020140000_animals.sql) creates the animal register.
   - [`supabase/migrations/20261020180000_farm_book.sql`](supabase/migrations/20261020180000_farm_book.sql) creates the farm book.
   - [`supabase/migrations/20261020210000_farm_operations.sql`](supabase/migrations/20261020210000_farm_operations.sql) adds roles, sites, births, deaths, feed, breeding, health, weights, sales, milk, land, and the shared-herd rules.
   - [`supabase/migrations/20261020220000_expenses.sql`](supabase/migrations/20261020220000_expenses.sql) adds expenses.
   - [`supabase/migrations/20261020230000_expense_details.sql`](supabase/migrations/20261020230000_expense_details.sql) adds kilos, the animal, people, days, litres, and a short detail.
   - [`supabase/migrations/20261020240000_farmos_sites.sql`](supabase/migrations/20261020240000_farmos_sites.sql) adds Piggery Site and Cattle/Poultry Site.
   - [`supabase/migrations/20261020250000_receipts.sql`](supabase/migrations/20261020250000_receipts.sql) stores the supplier and whether a receipt photo was attached.
   - [`supabase/migrations/20261020260000_traceability.sql`](supabase/migrations/20261020260000_traceability.sql) adds sheep, slaughtered status, origin, parents, purchase details, and sale, slaughter, death, and cull records.
3. Copy the example file and fill in the two values from the Supabase API settings:

```bash
cp env.example.json env.json
flutter run -d chrome --dart-define-from-file=env.json
```

The same file works for Android and iOS:

```bash
flutter run -d android --dart-define-from-file=env.json
flutter run -d ios --dart-define-from-file=env.json
```

You can pass the values without a file:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

If only one of the two values is set, or Supabase fails to start, the app stays on the on-device records and says so on the sign-in screen. The practice account above works in that mode. With Supabase connected, the code is sent only by text and is not shown on the screen.

## Where to host it

This is one farm and a handful of phones, not a public website with heavy traffic. Host the two pieces separately.

- **Phones:** the Android APK above. That is the copy that works with no internet. It does not need a server to record the day.
- **Database, login texts, and files:** [Supabase](https://supabase.com). Start on the free plan. Move to the Pro plan when the farm depends on the backups. Do not stand up your own database server for this size.
- **The website:** [Cloudflare Pages](https://pages.cloudflare.com). Upload `build/web` after `flutter build web`. It is a static site, a few megabytes, and the free plan includes HTTPS. People can add it to a home screen. It still needs a signal to open the first time. After that, the phone keeps a copy.

## Tests

```bash
flutter test
```
