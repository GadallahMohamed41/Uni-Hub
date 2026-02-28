# إعداد Firebase للمشروع

## الخطوة 1: إنشاء مشروع في Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اضغط على "Add project" (إضافة مشروع)
3. أدخل اسم المشروع (مثلاً: university-connect)
4. اتبع الخطوات لإنشاء المشروع

## الخطوة 2: تفعيل الخدمات المطلوبة

### Authentication:
1. في القائمة الجانبية، اختر **Build > Authentication**
2. اضغط على "Get started"
3. في تبويب "Sign-in method"، فعّل **Email/Password**

### Firestore Database:
1. اختر **Build > Firestore Database**
2. اضغط على "Create database"
3. اختر "Start in test mode" (للتطوير)
4. اختر أقرب موقع جغرافي لك

### Storage:
1. اختر **Build > Storage**
2. اضغط على "Get started"
3. اختر "Start in test mode"

## الخطوة 3: تثبيت FlutterFire CLI

افتح Terminal واكتب:

```bash
# تثبيت Firebase CLI
npm install -g firebase-tools

# تسجيل الدخول
firebase login

# تثبيت FlutterFire CLI
dart pub global activate flutterfire_cli
```

## الخطوة 4: ربط المشروع بـ Firebase

في مجلد المشروع، اكتب:

```bash
flutterfire configure
```

اتبع الخطوات:
1. اختر المشروع الذي أنشأته
2. اختر المنصات (Android, iOS, Web)
3. سيتم إنشاء ملف `lib/firebase_options.dart` تلقائياً

## الخطوة 5: تحديث main.dart

بعد تشغيل `flutterfire configure`، حدّث ملف `main.dart`:

```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // ... باقي الكود
}
```

## الخطوة 6: تشغيل التطبيق

```bash
flutter pub get
flutter run
```

## قواعد الأمان (Security Rules)

### Firestore Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // المستخدمين
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    // المنشورات
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
    
    // التعليقات
    match /comments/{commentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow delete: if request.auth.uid == resource.data.userId;
    }
  }
}
```

### Storage Rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /posts/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    
    match /avatars/{userId}.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

## هيكل قاعدة البيانات

```
firestore/
├── users/
│   └── {userId}/
│       ├── name: string
│       ├── email: string
│       ├── studentId: string?
│       ├── department: string?
│       ├── bio: string?
│       ├── avatarUrl: string?
│       ├── createdAt: timestamp
│       └── lastLogin: timestamp?
│
├── posts/
│   └── {postId}/
│       ├── userId: string
│       ├── userName: string
│       ├── userBio: string
│       ├── userAvatarUrl: string?
│       ├── text: string
│       ├── imageUrl: string?
│       ├── createdAt: timestamp
│       ├── likesCount: number
│       ├── commentsCount: number
│       └── likedBy: array<string>
│
└── comments/
    └── {commentId}/
        ├── postId: string
        ├── userId: string
        ├── userName: string
        ├── userAvatarUrl: string?
        ├── text: string
        └── createdAt: timestamp
```

## ملاحظات مهمة

1. **للتطوير فقط**: قواعد "test mode" تسمح لأي شخص بالقراءة والكتابة. استخدم القواعد أعلاه للإنتاج.

2. **Indexes**: قد تحتاج لإنشاء indexes في Firestore للاستعلامات المركبة. Firebase سيخبرك عند الحاجة.

3. **حدود الاستخدام المجاني**:
   - Firestore: 50,000 قراءة، 20,000 كتابة، 20,000 حذف يومياً
   - Storage: 5GB تخزين، 1GB تحميل يومياً
   - Authentication: غير محدود
