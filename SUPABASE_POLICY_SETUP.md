# إعداد Supabase Storage Policies - خطوة بخطوة

## ⚠️ ملاحظة مهمة:
الكود يستخدم bucket باسم `images`، لكن إذا أنشأت bucket باسم آخر (مثل `storge-university`)، يجب أن تغير Policy definition ليطابق اسم الـ bucket.

---

## Policy 1: للقراءة (Public Read) - SELECT

### الخطوات:
1. في صفحة **Storage** > **Policies**، اضغط على **New Policy**
2. اختر **For full customization**
3. **Policy name**: `Public Read`
4. **Allowed operation**: ✅ فعّل **SELECT** فقط
5. **Target roles**: اتركه كما هو (Defaults to all)
6. **Policy definition**: 
   ```sql
   bucket_id = 'images'
   ```
   أو إذا كان اسم bucket مختلف:
   ```sql
   bucket_id = 'storge-university'
   ```
7. اضغط **Review** ثم **Save policy**

---

## Policy 2: للرفع (Authenticated Upload) - INSERT

### الخطوات:
1. اضغط على **New Policy** مرة أخرى
2. **Policy name**: `Authenticated Upload`
3. **Allowed operation**: ✅ فعّل **INSERT** فقط
4. **Target roles**: يمكنك اختيار `authenticated` أو تركه كما هو
5. **Policy definition**:
   ```sql
   bucket_id = 'images' AND auth.role() = 'authenticated'
   ```
   أو:
   ```sql
   bucket_id = 'storge-university' AND auth.role() = 'authenticated'
   ```
6. اضغط **Review** ثم **Save policy**

---

## Policy 3: للحذف (Owner Delete) - DELETE (اختياري)

### الخطوات:
1. اضغط على **New Policy** مرة أخرى
2. **Policy name**: `Owner Delete`
3. **Allowed operation**: ✅ فعّل **DELETE** فقط
4. **Target roles**: اتركه كما هو
5. **Policy definition**:
   ```sql
   bucket_id = 'images' AND (storage.foldername(name))[1] = auth.uid()::text
   ```
   أو:
   ```sql
   bucket_id = 'storge-university' AND (storage.foldername(name))[1] = auth.uid()::text
   ```
6. اضغط **Review** ثم **Save policy**

---

## ملاحظات:

- إذا كان اسم الـ bucket في Supabase مختلف عن `images`، يجب:
  1. إما تغيير اسم الـ bucket في Supabase إلى `images`
  2. أو تغيير الكود في `lib/services/storage_service.dart` ليستخدم اسم الـ bucket الصحيح

- للتأكد من اسم الـ bucket:
  - اذهب إلى **Storage** في Supabase Dashboard
  - ستجد قائمة بالـ buckets
  - استخدم نفس الاسم في Policy definition

---

## التحقق من الإعداد:

بعد إنشاء Policies، جرب:
1. رفع صورة من التطبيق
2. عرض الصورة في التطبيق
3. إذا ظهرت أخطاء، تحقق من:
   - اسم الـ bucket في Policy definition
   - أن الـ bucket موجود و Public
   - أن Policies تم حفظها بنجاح
