# 4.0.2 — bodycam من الصدر، الشعار والرتب

## التركيب بلا خلط النسخ

1. وقف السيرفر كامل من txAdmin.
2. دير backup لفولدر crimson_doj خارج resources، خصوصاً config.lua والأصوات وrecordings.
3. حل ZIP ديال4.0.2 وحط فولدر crimson_doj كامل داخل [custom] كنسخة واحدة. فيه config وpermissions وmanifest وجميع modules اللي محتاجين.
4. إلاconfig ديالك مخصص، رجّع config.lua والأصوات وrecordings منbackup. permissions.lua وfxmanifest.lua وserver.lua وملفاتweb خدم بالجدد ديال هادZIP، حيثفيهم التغييرات المطلوبة.
5. شعل السيرفر كامل من txAdmin باش manifest الجديد يتقرا. ماشي غير ensure ديال resource قديمة ومازال metadata ديالها4.1.

ماكاين لا SQL import جديد لا item جديد. crimson_bodycam اللي سجلتيه فـox_inventory باقي نفسه. النسخة فيها حتى تصحيح Delete camera المباشر بلا JavaScript Confirm ديالWindows.

## Bodycam فعلياً من موضع الصدر

- client_bodycam.lua كيربط position ديال الكاميرا بموضع عظم الصدر، لقدّام الجسم بشوية، وكيحدّ زوايا النظر باش ما تدورش وتدخل فالجسم.
- السيرفر كيتأكد من الصلاحية والـitem، وكيستنى تأكيد تجهيز الكاميرا منclient قبل ما يبدأ screencapture.
- استعمل Record my bodycam أوitem كما قبل، وسدMDT باش تسجل اللعب. أثناء التسجيل حتى المنظور عندك كيتبدل لكاميرا الصدر، لأن provider كيسجل نفس الشاشة. ماشي كاميرا ثانية مخفية كتسجل لقطة مختلفة على اللي كتشوف.
- ملي يكمل التسجيل أوتوقفو، كترجع كاميرااللعب. provider-start failure أوlogout أوresource stop كيرجعو المنظور حتى هما. إلا ماتت الشخصية كيتحرر المنظور وكيتطلب توقيف التسجيل.
- ما تقدرش تفتح Security camera أثناء كاميراالصدر خدامة، وما كيبدأش التسجيل منداخل كاميرا scripted أخرى.
- الفيديوهات القديمة ماكيتبدلوش. جرب تسجيل جديد باش تشوف المنظور الجديد.
- نفس providerماكيعطيش صوت اللعبة. Live bodycam الخارجي ما تبدلش بهاد التحديث.

إلا بغيتي ترجع المنظور السابق للتسجيل، زيد فآخرconfig.lua:

```lua
Config.Bodycam.view = 'gameplay'
```

الافتراضي إلامازدتيهاش هو chest. تقدر تحدد Config.Bodycam.fov بين45و100، والافتراضي80. الكاميرا خاصها تجربة داخلFiveM معmodel الشخصية/اللباس والسيارات ديالك؛ الاختبارات هنا كتأكدposition/lifecycle/ownership وماشي تصويرengineحقيقي.

## الشعار

web/doj-logo.png هو نفسPNG الأصلي من doj logo.zip، بلا إعادة رسم ولا تبديل النصوص. مستعمل فـMDT وفـbadge. الـalpha/transparency ديالو محفوظة.

## ترتيب الرتب — الرقم الكبير أعلى

| Grade | الاسم |
|---|---|
| 0 | DOJ Trainee |
| 1 | Lawyer in Training |
| 2 | Municipal Security Officer |
| 3 | Court Clerk |
| 4 | Private Defender |
| 5 | Public Defender |
| 6 | Chief Public Defender |
| 7 | Prosecutor |
| 8 | Deputy District Attorney |
| 9 | District Attorney |
| 10 | Attorney General |
| 11 | Judge |
| 12 | Senior Judge |
| 13 | Deputy Chief of Justice |
| 14 | Chief of Justice |

Management من Senior Judge (12) وطالع. الأزرار والأفعال كتبقى خاضعة حتى لصلاحيات كلرتبة؛ هاد التغيير ماكيمنحش جميع الأفعال الإدارية لجميع الرتب. Chief/Deputy Chief (13/14) باقين مخولين بإصدارbadges كما قبل.

server_grade_names.lua كيستعمل Qbox GetJobs/CreateJobs باش يبدل غيرnames ديالالرتب الموجودة فالـruntime. كينسخ ويحافظ علىpayment وisboss وbankAuth وباقي خصائصjob، وماكيكتبش فوق qbx_core/shared/jobs.lua. كيتطبق كل مرةكيبدأresource. API الرسمي المتحققمنه: https://github.com/Qbox-project/qbx_core/blob/main/server/groups.lua

إلاشيgrade ماكاينش أصلاً فـQbox، كيبان warning بالأرقام الليناقصين؛ ماكيخترعش رتبة بلا راتب ولا كيبدلgrade ديالأي موظف. صيفطjobs.lua إذااحتجنا نكملوmissing nativelevels. Config.SyncDojGradeNames=false كيطفي runtime name sync إلابغيتي تديرnames يدوياً فـQbox.

## تجربة منبعدالتركيب

1. تأكد الشعاربان فـMDT وفـbadge.
2. جرّب DOJ grade11: Management مخفي. grade12/13/14: ظاهر. Businesses/Vehicle search/Units باقين حسبالصلاحيات السابقة.
3. سجلbodycam جديد، تحرك،وقفالتسجيل،وتأكدكاميرااللعب رجعات.
4. فتحالفيديو الجديد وتأكدالمنظور منموضعالصدر، بلا شخصيتك مناللور.
5. جرّبالserial وحذفكاميرا باشنتأكدوالوظائفالليخدامين بقاوخدامين.
