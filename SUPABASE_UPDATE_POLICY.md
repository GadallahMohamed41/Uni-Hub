# Policy لتحديث الصور (UPDATE) في Supabase

## إذا أردت أن يكون المستخدمون قادرين على تحديث/استبدال الصور:

### Policy 4: لتحديث الصور (UPDATE)

#### الخطوات:
1. في صفحة **Storage** > **Policies** للـ bucket `images`
2. اضغط على **New Policy**
3. اختر **For full customization**
4. **Policy name**: `Update Own Files`
5. **Allowed operation**: ✅ فعّل **UPDATE** فقط
6. **Target roles**: اتركه كما هو أو اختر `authenticated`
7. **Policy definition**: 
   ```sql
   bucket_id = 'images' AND (storage.foldername(name))[1] = auth.uid()::text
   ```
   هذا يسمح للمستخدم بتحديث الملفات في مجلده فقط (posts/userId/ أو avatars/userId.jpg)

8. اضغط **Review** ثم **Save policy**

---

## ملاحظات:

### للصور العادية (Posts):
- الكود الحالي يستخدم `upsert: false` - يعني لا يمكن استبدال الصورة
- إذا أردت السماح بالاستبدال، يمكن تغيير `upsert: false` إلى `upsert: true` في الكود

### لصور البروفايل:
- الكود الحالي يستخدم `upsert: true` - يعني يمكن استبدال الصورة
- هذا يعمل تلقائياً عند رفع صورة بروفايل جديدة

---

## الخلاصة:

**إذا أردت تحديث الصور:**
1. أنشئ Policy للـ UPDATE (كما هو موضح أعلاه)
2. للصور العادية: غير `upsert: false` إلى `upsert: true` في الكود (اختياري)

**إذا لم ترد تحديث الصور:**
- لا حاجة لـ UPDATE Policy
- الصور ستُرفع مرة واحدة فقط
