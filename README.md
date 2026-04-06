<div align="center">
  <img src="assets/logo.png" alt="ShieldHer Logo" width="150"/>
  <h1>ShieldHer</h1>
  <p><b>A comprehensive personal safety and community support application built with Flutter.</b></p>
</div>

---

## 🛡️ About ShieldHer

ShieldHer is an innovative safety application designed to empower users, especially women, with tools to stay secure, connected, and informed. From quick access to emergency services to trusted community tracking and discreet recording, ShieldHer provides an all-in-one safety ecosystem right in your pocket. 

## ✨ Key Features

- 🚨 **Emergency SOS**: Quick access to authorities and pre-selected emergency contacts. 
- 📴 **Offline Support**: Access and manage your emergency contacts even without an active internet connection. Your safety shouldn't depend on a network signal.
- 📞 **Discreet Fake Call**: Trigger a realistic, slide-to-answer "fake call" to gracefully escape uncomfortable or potentially dangerous situations.
- 🎙️ **Incident Recording**: Quickly and discreetly record audio evidence with the press of a button.
- 📍 **Trusted 'Bubble' & Live Tracking**: Create your secure community or "Bubble". Share your live whereabouts with trusted members via an interactive map ensuring someone always has your back.
- 📚 **Safety Learning**: Access educational self-defense resources and safety tips directly through the app.

## 📱 Screenshots
*(Add screenshots of your application here)*

| Home Screen | Emergency Contacts | Community / Bubble | Fake Call Screen |
| :---: | :---: | :---: | :---: |
| <img src="" width="200" /> | <img src="" width="200" /> | <img src="" width="200" /> | <img src="" width="200" /> |

## 🛠️ Tech Stack

- **Frontend**: [Flutter](https://flutter.dev/) & Dart
- **Backend & Auth**: [Supabase](https://supabase.com/)
- **Authentication**: Email/Password and Google Sign-In
- **Mapping & Location**: `flutter_map`, `latlong2`, and `geolocator`
- **Device Features**: 
  - `record` & `audioplayers` for discrete audio capturing 
  - `flutter_native_contact_picker` for fetching contacts
  - Hardware button integrations (Volume button triggers)

## 🚀 Getting Started

Follow these steps to set up the project locally on your machine.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.8 or newer)
- [Dart SDK](https://dart.dev/get-dart)
- An active [Supabase](https://supabase.com/) account and project.
- Android Studio or Xcode (for iOS development).

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/vaibhavsurani/SHIELDHER.git
   cd SHIELDHER
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase & Environment Variables**
   - Create a `.env` file in the root of your project or setup Supabase configuration directly where it initializes (often inside `lib/main.dart` or an environment config file).
   - Add your Supabase `URL` and `ANON_KEY`.

4. **Run the Application**
   ```bash
   flutter run
   ```

## 📂 Project Structure

```text
lib/
 ┣ screens/               # Application UI Screens (Home, Login, Community, etc.)
 ┣ services/              # API interfaces, Supabase services, Background handlers
 ┣ theme/                 # App-wide UI styling, colors, and typography 
 ┣ widgets/               # Reusable custom UI components 
 ┣ auth_gate.dart         # Authentication routing logic
 ┗ main.dart              # Entry point 
```

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! 
Feel free to check the [issues page](https://github.com/vaibhavsurani/SHIELDHER/issues) if you want to contribute.

## 📝 License

This project is licensed under the [MIT License](LICENSE).
