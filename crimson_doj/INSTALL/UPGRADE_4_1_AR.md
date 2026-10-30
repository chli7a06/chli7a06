# Crimson 4.1 preview — التحديث من 4.0

النسخة 4.0 جربتيها فالسيرفر وقلتي الوظائف خدامين. هاد التحديث كيزيد الفرنسية، Air units، البحث فـserial ديال السلاح، وإدارة مواقع الكاميرات. النسخة الجديدة خاصها تجربة داخل FiveM حتى هي.

## التركيب

1. وقف crimson_doj ودير backup للـresource والـdatabase والـrecordings.
2. بدّل ملفات crimson_doj من ZIP الجديد، مع الاحتفاظ بـconfig.lua وpermissions.lua المخصصين والأصوات وrecordings. defaults.lua الجديد ضروري؛ فيه fallback للإعدادات الجديدة. config ديالك ما خاصوش يتبدل بواحد آخر بلا مقارنة.
3. ما كاين لا item جديد لا table جديد فـ4.1. تعريفات 4.0 كتبقى نفسها. bridge ديال Origen وpatch ديال lb-phone كيبقاو كيفما كانوا.
4. تأكد qbx_vehiclekeys خدام قبل crimson_doj إلا بغيتي الهليكوبتر، ومن بعد ensure crimson_doj. ما كتحتاجوش باش يستعملو باقي MDT.

## الفرنسية

Config.Locale الافتراضي هو fr. تقدر تزيد فآخر config.lua:

```lua
Config.Locale = 'fr' -- أو en
```

الترجمة كتشمل عناوين وأزرار وحقول ورسائل الواجهة، الـbadge، والوثائق المطبوعة من ناحية الأزرار. أسماء الناس، الرتب المخصصة، القوانين، أسماء الشركات ومحتوى الدوسيات/الوثائق ما كيتبدلوش. diagnostics اللي جايين من providers أو server ممكن يبقاو بالإنجليزية. ملفات الترجمة المرجعية فـweb/locales/fr.json؛ runtime كيستعمل النسخة المجمعة فـweb/i18n.js، خاصهم يبقاو متزامنين إلا عدلتي الترجمة.

## Air units — سطح Mission Row

OPERATIONS → Unités aériennes. خاص DOJ/police/sheriff، grade10+ وصلاحية الكتابة، وتكون حدا الهليپاد. الزر GPS de l’héliport كيعطيك waypoint، ما كيديرش teleport.

الإعداد الافتراضي:

```lua
Config.AirUnits = {
 mission_row = {
  label='Mission Row',jobs={doj=true,police=true,sheriff=true},grade=10,
  model='polmav',livery=0,radius=12,
  coords={x=449.2901,y=-981.1782,z=43.6913,w=86.4242},
 },
}
```

model وcoords كيجيو غير من config ديال السيرفر. مفاتيح qbx_vehiclekeys:GiveKeys(source,vehicle,true) حسب [API الرسمي المتحقق منه](https://github.com/Qbox-project/qbx_vehiclekeys/blob/main/server/keys.lua). الهليكوبتر وحدة لكل شخص، cooldown60ثانية، ونقطة الخروج خاصها تكون خاوية. Restituer كيتطلب ترجع لنفس الهليپاد، تخرج نتا والركاب، ونفس routing bucket. الوحدات مؤقتة؛ resource stop كيحيد غير الطائرات اللي صرفها بنفسه. ما كاينش أخذ طائرة ديال لاعب آخر أو شراء/بيع. إلا عندك MLO مبدل السطح، عدل coords للمكان الصحيح قبل الطلب. EMS ما تزادتش ليه نقطة افتراضية.

## Recherche de numéro de série

OPERATIONS → Recherche de numéro de série. من بعد حوالي دقيقة من دخول اللاعبين، كيتسجل serial ديال الأسلحة اللي كاينة فـonline ox_inventory. كتقلب بثلاثة حروف على الأقل. كيبان آخر CID كان حاملها وmetadata.registered إلا موجودة. هادشي observation ديال الحيازة، ماشي إثبات الملكية القانونية ولا تسجيل تلقائي ديال كل مخزن/offline/stash. Registre des armes اليدوي باقي باش توثق الملكية أو التحقيق.

```lua
Config.WeaponObservation = true -- false باش تطفي المسح
```

## Réseau de caméras

OPERATIONS → Réseau de caméras. خاص legal department، صلاحية vehicles_view وManagement gate. الإضافة/التعديل/الحذف خاصهم حتى manager/write permission. Ajouter une caméra à ma position كيسجل position الحالية ديالك من السيرفر، زائد متر فالعلو. كتحدد inclination، orientation وFOV. الكاميرا كتبقى فالمكان حتى تختار تحركها. كل تعديل فيه version باش ما يتمسحش تعديل شخص آخر.

الكاميرات مسجلة فـdatabase حسب scope وrouting bucket. View camera كيستعمل نفس native viewer وEsc للخروج. هادي view ديال عالم اللعبة، ماشي recording ولا تصوير حقيقي لداخل interior ما محملش. Config.Cameras القديمة باقية فـEquipment & cameras. ماكينش نشر لكل كاميرات المدينة أوتوماتيكياً؛ كتضيف غير المواقع المطلوبة فـMLO ديالك.

## شنو باقي خارج المطابقة

مازال ما كنقولوش مطابق لـXR بنسبة100%. live بالصوت ما كيدعموش provider الحالي؛ livevideo خاص Cloudflare Worker ديالك. ماكاينش arbitrary HTML/PDF page builder ولا automatic debt collection ولا مزامنة records/assignments الداخلية ديال Origen بلا API موثق. الطباعة من رابط الصورة والتوقيعات والأرشيف باقيين خدامين كما فـ4.0. هاد التحديث ما كيبدلش نظام الفلوس الخدام.

## الاختبار فالسيرفر

- حل MDT وتأكد الفرنسية، ومحتوى وثيقة قديمة ما تبدلش.
- جرّب grade0: ما يقدرش يخرج طائرة أو يدير كاميرا إدارية.
- grade14 فوق السطح: waypoint، spawn، keys، منع duplicate، إرجاع بعد ما يخرجو الركاب.
- جرّب serial ديال سلاح معروف فـinventory بعد دقيقة؛ قارن الرقم وCID.
- زيد كاميرا فموقع مطلوب، شوفها وخرج بـEsc، ريستارطي resource وتأكد بقات محفوظة.
