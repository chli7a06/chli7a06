# 4.0.1 — نفس أساس 4.0 اللي جربتي + serial والكاميرات

الأساس هو crimson_doj_4.0.0_preview (1).zip اللي صيفطتي وأكدتي أنه خدام. قارنّاه مع ZIP المنشورة4.0: نفس الملف. هاد النسخة كتزيد غير بحثserial ومعلومات آخر حائز، وإدارة الكاميرات من MDT.

كود app.js وطريقة فتح MDT والماوس بقوا كيف4.0. الفرق الوحيد فـclient.lua هو اختيار الكاميرا الجديدة. ما فيهاش انتظار UI acknowledgement ولا إغلاق8ثواني ولا polling ديال4.1. التحقق من هاد الفرق كيدوز فـtests/stable_base.test.py، بالإضافة لاختبارات الوظائف والصلاحيات.

## التركيب

1. وقف resource: stop crimson_doj.
2. احتافظ بنسخة من الفولدر الحالي خارج resources، خصوصاً config.lua وpermissions.lua والأصوات وrecordings.
3. حل crimson_doj_4.0.1_cameras_serial.zip. فيه فولدر crimson_doj كامل، حتى config.lua وpermissions.lua وpenal_code.lua. استعمل هاد الفولدر كـresource واحد؛ ما تخليش جوج نسخ بنفس الاسم خدامين.
4. إلا config أو permissions عندك مخصصين، رجع النسخ الخدامة ديالك منbackup. رجع حتى الأصوات والrecordings. باقي ملفات runtime/web خدم بالجدد كاملين باش ما يتخلطوش مع4.1.
5. ensure crimson_doj. ما كاين لا SQL import جديد لا item جديد. جداول وdocuments4.0 كتبقى محفوظة فـdatabase. ما تمسح حتى table.

إلا راك دابا مركب4.0 الأصلية، تقدر تنسخ النسخة الجديدة فوقها مع الحفاظ على config/permissions/sounds/recordings. إلا راك مركب4.1، النسخة الكاملة هنا كترجع ملفات الفتح والواجهة ديال4.0؛ ما تستعملش hotfix4.1 فوقها.

## البحث بـserial

OPERATIONS → Weapon serial search.

- خاص DOJ/police/sheriff وصلاحية vehicles_view وواجب الخدمة حسب config.
- دخل serial كامل أو3حروف على الأقل.
- السيرفر كيفحص inventories ديال اللاعبين المتصلين كل60ثانية، من ox_inventory.
- كيبان السلاح، serial، اسم وCID ديال آخر حائز تسجّل، registered-name metadata إلا موجودة، وآخر وقت observation.
- هادي حيازة لوحظت فـinventory، ماشي إثبات الملكية القانونية. ما كيتمش مسح offline/stash inventories، وماشي history ديال كل تحويلات السلاح.
- باش تطفي المسح: Config.WeaponObservation=false فـconfig.lua.

Registre/Weapon registry اليدوي باقي كما كان فـ4.0.

## إضافة وتعديل الكاميرات

OPERATIONS → Camera network.

- خاص legal department وvehicles_view وManagement gate ديال4.0. الإضافة/التعديل/الحذف كيتطلبو حتى manager/write permission. DOJ Chief/Judge grade13/14 مؤهلين بالإعدادات الحالية.
- Add camera at my position: position كتتاخذ من السيرفر، متر فوق اللاعب. حدد الاسم وtilt وheading وFOV.
- Edit camera: بدل الاسم والزاوية وFOV. إلا بغيتي تحركها، اختار Move camera to my current position؛ بلا هاد الخيار كتبقى فبلاصتها.
- View camera ثم Esc للرجوع للـMDT.
- Delete camera فيه confirmation وversion check. إلا شي حد سبق وعدلها، خاص refresh.
- الكاميرات محفوظة فـcrimson_mdt_entities حسبscope وrouting bucket. كتستمر بعدrestart. المواقع داخلMLO خاصها تكون مناسبة باش viewتبان مزيانة.

Config.Cameras القديمة باقية فـEquipment & cameras. هاد الكاميرات هي native views ديال عالم اللعبة، ماشي recordings ولا livebodycam.

## التجربة

أولاً جرّب فتح MDT والماوس والإغلاق كما فـ4.0. من بعد جرّب serial معروف فـinventory بعددقيقة. جرّب زيدكاميرا،شوفها،عدّلها وrestart باش تتأكد بقات محفوظة. الاختبارات الآلية دازت؛ الإضافتان باقي خاصهما قبول داخل FiveM عندك.
