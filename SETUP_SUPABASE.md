# دليل إعداد Supabase Storage - خطوة بخطوة

## 📌 ملاحظة مهمة:
**Firebase لن يُلغى!** 
- ✅ Firebase سيظل مستخدماً للـ **Authentication** (تسجيل الدخول)
- ✅ Firebase سيظل مستخدماً لـ **Firestore** (المنشورات، التعليقات، المستخدمين)
- ✅ Supabase سيستخدم فقط لتخزين **الصور** (بديل مجاني لـ Firebase Storage)

---

## الخطوة 1: إنشاء حساب Supabase

1. اذهب إلى [https://supabase.com](https://supabase.com)
2. اضغط على **Start your project** أو **Sign Up**
3. سجل بحساب Google أو GitHub أو Email
4. بعد التسجيل، اضغط على **New Project**

---

## الخطوة 2: إنشاء مشروع جديد

1. في صفحة **New Project**:
   - **Name**: اختر اسم للمشروع (مثلاً: `my-app-storage`)
   - **Database Password**: اختر كلمة مرور قوية (احفظها!)
   - **Region**: اختر أقرب منطقة لك
   - **Pricing Plan**: اختر **Free** (مجاني حتى 1GB)

2. اضغط على **Create new project**
3. انتظر حتى يتم إنشاء المشروع (دقيقة أو دقيقتين)

---

## الخطوة 3: الحصول على API Keys

1. بعد إنشاء المشروع، اذهب إلى **Settings** (في القائمة الجانبية)
2. اضغط على **API**
3. ستجد القيم التالية:
   - **Project URL**: رابط يبدأ بـ `https://` وينتهي بـ `.supabase.co`
   - **anon public key**: مفتاح طويل يبدأ بـ `eyJhbGci...`

4. انسخ القيمتين

---

## الخطوة 4: إنشاء Storage Bucket

1. في Supabase Dashboard، اضغط على **Storage** (في القائمة الجانبية)
2. اضغط على **Create a new bucket**
3. في النافذة المنبثقة:
   - **Name**: اكتب `images`
   - **Public bucket**: فعّل هذا الخيار (Public)
   - اضغط على **Create bucket**

---

## الخطوة 5: إعداد Storage Policies (قواعد الأمان)

### 5.1: Policy للقراءة (Public Read)

1. في صفحة Storage، اضغط على **Policies** بجانب bucket `images`
2. اضغط على **New Policy**
3. اختر **For full customization**
4. في **Policy name**: اكتب `Public Read`
5. في **Allowed operation**: اختر **SELECT**
6. في **Policy definition**: الصق الكود التالي:

```sql
bucket_id = 'images'
```

7. اضغط على **Review** ثم **Save policy**

### 5.2: Policy للكتابة (Authenticated Users)

1. اضغط على **New Policy** مرة أخرى
2. **Policy name**: `Authenticated Upload`
3. **Allowed operation**: اختر **INSERT**
4. **Policy definition**: الصق:

```sql
bucket_id = 'images' AND auth.role() = 'authenticated'
```

5. اضغط على **Review** ثم **Save policy**

### 5.3: Policy للتعديل والحذف (Owner Only)

هذه القاعدة تسمح للمستخدم بتغيير صورة البروفايل الخاصة به أو حذف صور منشوراته.

1. اضغط على **New Policy** مرة أخرى
2. **Policy name**: `Owner Update and Delete`
3. **Allowed operation**: اختر **UPDATE** و **DELETE** (يمكنك اختيار الاثنين معاً أو إنشاء قاعدة لكل واحد)
4. **Policy definition**: الصق الكود التالي (هذا يضمن أن المستخدم يتحكم فقط في ملفاته):

```sql
bucket_id = 'images' AND (
  name = 'avatars/' || auth.uid() || '.jpg' 
  OR 
  name LIKE 'posts/' || auth.uid() || '/%'
)
```

5. اضغط على **Review** ثم **Save policy**

---

## الخطوة 6: تحديث ملف الإعدادات في التطبيق

1. افتح ملف `lib/config/supabase_config.dart` في التطبيق
2. استبدل القيم:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';  // الصق Project URL هنا
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';  // الصق anon key هنا
}
```

**مثال:**
```dart
class SupabaseConfig {
  static const String url = 'https://abcdefghijklmnop.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZmdoaWprbG1ub3AiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTYxNjIzOTAyMiwiZXhwIjoxOTMxODE1MDIyfQ.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
}
```

---

## الخطوة 7: تثبيت Dependencies

افتح Terminal في مجلد المشروع وقم بتشغيل:

```bash
flutter pub get
```

---

## الخطوة 8: اختبار التطبيق

1. شغّل التطبيق:
   ```bash
   flutter run
   ```

2. جرب رفع صورة:
   - أنشئ منشور جديد مع صورة
   - أو غيّر صورة البروفايل

3. تحقق من Supabase Dashboard:
   - اذهب إلى **Storage** > **images**
   - يجب أن ترى الصور المرفوعة

---

## استكشاف الأخطاء

### ❌ خطأ: "Invalid API key"
- تأكد من نسخ `anon key` بشكل صحيح
- تأكد من عدم وجود مسافات إضافية

### ❌ خطأ: "Bucket not found"
- تأكد من إنشاء bucket باسم `images` بالضبط
- تأكد من تفعيل **Public bucket**

### ❌ خطأ: "new row violates row-level security policy"
- تأكد من إعداد Policies بشكل صحيح
- تأكد من تفعيل **Public bucket**

### ❌ الصور لا تظهر
- تحقق من أن الـ URL صحيح في Firestore
- تحقق من أن الصورة موجودة في Supabase Storage

---

## البنية النهائية

```
التطبيق
├── Firebase Authentication (تسجيل الدخول)
├── Firestore (المنشورات، التعليقات، المستخدمين)
└── Supabase Storage (الصور فقط)
```

---

## المزايا

- ✅ **مجاني حتى 1GB** من التخزين
- ✅ **Firebase لا يُلغى** - يستمر في العمل للـ Auth و Firestore
- ✅ **سريع وموثوق** مع CDN عالمي
- ✅ **سهل الإعداد**

---

## ملاحظات إضافية

- يمكنك إزالة `firebase_storage` من `pubspec.yaml` إذا أردت (لكن ليس ضرورياً)
- الصور تُخزن في Firestore كـ **URLs فقط** (كما كان من قبل)
- البيانات الفعلية تبقى في **Firestore**

---

## الدعم

إذا واجهت أي مشاكل:
1. تحقق من Console للأخطاء
2. راجع [Supabase Documentation](https://supabase.com/docs)
3. تحقق من أن جميع الخطوات تمت بشكل صحيح

---

**تم! 🎉** الآن التطبيق يستخدم Supabase لتخزين الصور و Firebase للباقي.