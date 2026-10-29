# تركيب Crimson 4.0 preview

هاد النسخة كتزيد وظائف مستقلة؛ ماشي نسخة مطابقة لـ XR ولا تعويض لـ Origen.

1. دير backup لفولدر crimson_doj وdatabase وملفات recordings قبل التحديث. وقف crimson_doj.
2. بدّل ملفات resource بالمجلد crimson_doj اللي فـZIP. احتافظ بالتعديلات ديالك فـconfig.lua وpermissions.lua وبالأصوات والـrecordings. قارن config مع الجديد، ما تمسحش config خدام بلا مقارنة.
3. الـschema كيخلق الجداول الجديدة أوتوماتيكياً. ما تمسح حتى table قديم. اسم resource يبقى crimson_doj.
4. زيد غير تعريفات crimson_bodycam وcrimson_tracking_band داخل return الموجود فـox_inventory/data/items.lua، من NEW_ITEMS_4.lua. إلا document/badge مسجلين ما تعاودش تزيدهم. ما تضيفش return ثاني. electronickit خاص يكون موجود حيث مستعمل ففك tracker.
5. زيد إعدادات New options اللي لتحت فآخر config.lua، حسب السيرفر. defaults.lua فيه fallback إلا مازدتيهمش.
6. للربط مع Origen: انسخ الملف الصغير integrations/origen-police/crimson_bridge.lua إلى origen_police/custom/server/menu/crimson_bridge.lua. الـfxmanifest اللي صيفطتي كيقرا هاد المسار. ريستارطي origen_police ومن بعد crimson_doj. ما تبدلش ملفات Origen المشفرة أو HTML.
7. خليهـم يبداو قبل crimson_doj: qbx_core، ox_lib، oxmysql، ox_inventory، ox_target، apex_banking؛ screencapture إلا غادي تستعمل bodycam. فـconsole: ensure crimson_doj. إعادة ox_inventory أحسن تكون فـrestart منظم للسيرفر.

## New options — مثال فـconfig.lua

```lua
Config.DiscoverBusinesses = true -- jobs الحقيقية ديال Qbox
Config.BusinessExcludedJobs = { unemployed = true }
Config.StockArmory = true
Config.ArmoryCatalog = {
 {name='radio',label='Radio',grade=0},
 -- زيد items مسجلين عندك، وبـgrade المناسب
}
Config.RequireBodycamItem = true
Config.BodycamItem = 'crimson_bodycam'
Config.EnableLiveBodycam = false
Config.DispatchSources = { origen_police = true }
Config.AutomaticGunshots = true
Config.Tracking = {enabled=true,item='crimson_tracking_band',tool='electronickit',grade=5,bypassGrade=10}
```

خلي Config.Banking.provider على apex_banking اللي خدام عندك. ماتبدلش patch ديال lb-phone اللي تصلح. إلا عندك system آخر كيصدر gunshot alerts، طفي AutomaticGunshots باش تتجنب alerts مكررة.

## فين تلقى الإضافات

- Citizens → اختار المواطن: الصورة، الهاتف، wanted، الرخص، notes، conviction history. Record conviction كيحسب قوانين السيرفر؛ ماكيحيدش الفلوس وماكيدخلش الحبس بوحدو. التنفيذ باقي من legal actions المرتبطة بالقضية.
- Vehicle search فـOPERATIONS: فتح ملف plate مسجل، الصورة/notes/wanted.
- القضية → Participants, vehicles & evidence: IDs/roles، plates وصور. الأدلة صورة برابط مسموح؛ ماشي نقل تلقائي لأدلة Origen.
- Businesses فـADMINISTRATION: ملف الشركة، المالك، logo، status، الموظفين والحساب. كل jobs ديال Qbox كتبان؛ اللي ماعندهاش account ماكيتمش اختراع حساب ليها.
- Employees → Inspector: CID، badge number، notes، duty time وsuspension. Management grade10+ مع صلاحية الرتبة. Suspension كيمنع Crimson MDT؛ ماكيوقفش كل أنظمة Origen أو job بوحدو.
- Statistics فـOVERVIEW: سجلات Crimson، authors، custody totals وduty time. ماشي إحصائيات شاملة لسيرفر كامل أو Origen.
- Documents: Heading/Bold/Bullet/Preview وSigner citizen IDs. التوقيع كيدار من النسخة المطبوعة اللي فـinventory وبالـCID المحدد. الطباعة غير من ox_target printer، ماكاينش direct print inventory button.
- Document archive: deposit كيسحب النسخة المادية، retrieve كيرجع نفس النسخة. خاصك تكون حدا printer ديال القسم، وretrieve/list لـManagement. الوثيقة الأصلية كتبقى فـMDT.
- Armory: خاصك تكون فالموقع؛ stock كيبدا صفر. Manager يعمره من Replenish حسب catalog. cart، kits شخصية، وreturns ديال المعدات المصروفة. ماشي شراء بمصاريف حقيقية؛ التعمار قرار إداري.
- Tracking bands: grade5+، target حاضر حداك ونفس routing bucket وقضية صحيحة. المستهدف يقدر يجرب /removeband بـelectronickit وskill check؛ grade10+ عندو bypass مع نفس tool. blips كيتحيدو إلا خرج الشخص/تبدل duty أو الصلاحية.
- Dispatch: calls يدوية أو gunshots أو import alerts ديال Origen؛ Responding units مستقل فـCrimson. ماكيزامنش assignments ولا records ديال Origen.
- badge: باقية chief-issued item مع e idcard وBackspace، ماتزاد حتى command للتصنيع الذاتي.

## Sounds

حط الملفات ديالك هنا: crimson_doj/web/sounds/open.ogg، close.ogg، click.ogg، notification.ogg. بدّل الأسماء/volume فـConfig.Sounds إلا بغيتي. ZIP ماكيحتويش أصوات XR.

## Live bodycam

الفيديو المسجل كيحتاج screencapture وitem. Live خاص إعداد Cloudflare SFU Worker ديال screencapture من documentation ديالو، ثم convar screencapture_live_endpoint برابط HTTPS، وConfig.EnableLiveBodycam=true. الـWorker/service credentials يبقاو server-side؛ مايتحطوش فـweb. المشاهد كيستقبل viewer token مؤقت ومرة واحدة؛ host خاصو يشعل live ديالو بنفسو. الفيديو بلا audio: provider ماكيعطيش صوت اللعبة. هاد الرفع ماكيقومش بنشر Worker أو تزويد service account نيابة عليك.

## Interrupted inventory operations

إلا وقع crash وسط نقل item، العملية كتبقى pending باش ماتعاودش item أو stock بالغلط. console فقط: crimsonreview كيعرضها. من بعد ما admin يتأكد من inventory/database يستعمل crimsonresolveitem حسب help اللي كيطبع. هاد command كيصحح journal فقط؛ ماكيحرك لا item لا stock لا money. صلح stock بشكل منفصل بعد reconciliation. ما تديرش replay عشوائي. crimsonunsuspend <citizenid> <job> كيرفع Crimson suspension من console.

## تجربة ضرورية داخل FiveM

جرّب DOJ grade0 وgrade14 وmecano؛ permissions الممنوعة خاص تترفض حتى من callback. جرّب document مع signer صحيح وآخر، printer/archive/inventory-full، armory issue/return/stock-empty، tracker بجوج لاعبين وrouting buckets مختلفين، Origen alert والرخص، وحساب mecano مع lb-phone. tests الآلية دازت فبيئة التطوير، ولكن ما تشغلاتش game natives فـFiveM هنا.
