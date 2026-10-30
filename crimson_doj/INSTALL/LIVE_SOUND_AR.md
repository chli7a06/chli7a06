# Live access and printer sound
مشاهدة live bodycam خاصة فقط بـDOJ Senior Judge (grade12 بالضبط)، حتىChief وDeputy مامسموحش ليهم. الفحص server-side قبل وبعد viewer token وعند المراقبة الدورية. باقي الموظفين يقدرو يشعلو/يوقفو بثهم بالشروط السابقة.
البث المباشر يحتاج إعداد screencapture Cloudflare Worker endpoint وتفعيل Config.EnableLiveBodycam؛ النسخة ماكتنشرش هاد الخدمة بوحدها.
حط ملف الصوت اللي عندك printer.mp3 داخل crimson_doj/web/sounds/printer.mp3. الصوت كيتسمع عند اللاعب ملي الطباعة كتنجح فعلياً. ماكاينش ملف صوت مرفق فالصورة، لذلك خاص تنسخو من عندك. Config.Sounds.printer = 'printer.mp3'.
الصوت ديال game/voice فالتسجيل وlive مازال غير مدعوم: provider الحالي كيعطي video فقط. خاص provider بإمكانية audio capture وربط audio tracks مع recorder وlive؛ ماشي مجرد unmute للفيديو. هاد النسخة ماكتدعيشش دعم الصوت.
