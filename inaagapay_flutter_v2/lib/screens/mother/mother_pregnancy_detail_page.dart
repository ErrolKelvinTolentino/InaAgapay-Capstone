// lib/screens/mother/pregnancy_detail_page.dart
//
// "More Info" page — personalized pregnancy companion
// Opened from MotherDashboard when the user taps "More Info"
// Connects to Supabase for risk assessments, symptoms, and personalized data

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/small_info_box.dart';
import '../../services/language_service.dart';
import '../../services/supabase_service.dart';

// ============================================
// DATA MODELS (moved to separate file in production)
// ============================================

class _TrimesterData {
  final String name;
  final String weeks;
  final IconData icon;
  final String headline;
  final String summary;
  final List<String> babyDevelopment;
  final List<String> motherChanges;
  final List<_Symptom> commonSymptoms;
  final List<_ChecklistItem> checklistItems;
  final List<_NutritionTip> nutritionTips;
  final List<_WarningSigns> warningSigns;
  final List<String> medicalVisits;
  final String emotionalNote;

  _TrimesterData({
    required this.name,
    required this.weeks,
    required this.icon,
    required this.headline,
    required this.summary,
    required this.babyDevelopment,
    required this.motherChanges,
    required this.commonSymptoms,
    required this.checklistItems,
    required this.nutritionTips,
    required this.warningSigns,
    required this.medicalVisits,
    required this.emotionalNote,
  });
}

class _Symptom {
  final String name;
  final String tip;
  final IconData icon;
  const _Symptom(this.name, this.tip, this.icon);
}

class _ChecklistItem {
  final String task;
  final bool urgent;
  const _ChecklistItem(this.task, {this.urgent = false});
}

class _NutritionTip {
  final String food;
  final String benefit;
  final IconData icon;
  _NutritionTip(this.food, this.benefit, this.icon);
}

class _WarningSigns {
  final String sign;
  final bool isEmergency;
  const _WarningSigns(this.sign, {this.isEmergency = false});
}

// ============================================
// STATIC CONTENT (Trimesters 1-3)
// ============================================

final _trimesterContent = [
  _TrimesterData(
    name: 'First Trimester',
    weeks: 'Weeks 1 – 13',
    icon: Icons.spa_outlined,
    headline: 'Your baby is just beginning!',
    summary:
        'The first trimester is a time of incredible transformation. Your body is working overtime to build a life, and your baby grows from a single cell into a fully formed tiny human with a heartbeat.',
    babyDevelopment: [
      'Week 4 – Embryo implants; neural tube begins forming',
      'Week 6 – Heart starts beating',
      'Week 8 – All major organs are forming; fingers and toes appear',
      'Week 10 – Baby can move, though you can\'t feel it yet',
      'Week 12 – Kidneys produce urine; baby can yawn and hiccup',
      'Week 13 – Fingerprints are forming; the baby continues to grow rapidly',
    ],
    motherChanges: [
      'Breast tenderness and swelling',
      'Frequent urination',
      'Fatigue and needing more sleep',
      'Heightened sense of smell',
      'Uterus growing but not yet visible',
      'Blood volume increases by up to 50%',
    ],
    commonSymptoms: [
      _Symptom('Morning sickness',
          'Eat small, frequent meals. Ginger tea helps.', Icons.sick_outlined),
      _Symptom('Fatigue', 'Rest as much as possible. Short naps are fine.',
          Icons.bedtime_outlined),
      _Symptom(
          'Food aversions',
          'Eat what you can tolerate. Bland foods often work.',
          Icons.no_food_outlined),
      _Symptom('Mood swings', 'Hormones are shifting. Journaling can help.',
          Icons.mood_outlined),
      _Symptom('Bloating', 'Avoid gas-producing foods; eat slowly.',
          Icons.bubble_chart_outlined),
    ],
    checklistItems: [
      _ChecklistItem('Schedule first prenatal checkup', urgent: true),
      _ChecklistItem('Start prenatal vitamins with folic acid', urgent: true),
      _ChecklistItem('Avoid alcohol, smoking, and raw foods'),
      _ChecklistItem('Inform your midwife of all medications'),
      _ChecklistItem('Get blood type and Rh factor confirmed'),
      _ChecklistItem('Discuss genetic screening options'),
      _ChecklistItem('Start a pregnancy journal'),
    ],
    nutritionTips: [
      _NutritionTip('Folic acid (leafy greens)', 'Prevents neural tube defects',
          Icons.emoji_food_beverage),
      _NutritionTip('Iron (red meat, beans)', 'Supports baby\'s blood supply',
          Icons.health_and_safety_outlined),
      _NutritionTip(
          'Calcium (dairy, tofu)', 'Builds bones and teeth', Icons.egg),
      _NutritionTip('Vitamin B6 (bananas)',
          'Reduces nausea and supports energy', Icons.emoji_food_beverage),
      _NutritionTip('Water (8+ glasses/day)', 'Prevents dehydration and UTIs',
          Icons.opacity),
    ],
    warningSigns: [
      _WarningSigns('Heavy vaginal bleeding', isEmergency: true),
      _WarningSigns('Severe abdominal pain', isEmergency: true),
      _WarningSigns('High fever above 38°C', isEmergency: true),
      _WarningSigns('Painful or burning urination'),
      _WarningSigns('Signs of depression or anxiety'),
    ],
    medicalVisits: [
      'First prenatal visit (confirm pregnancy, blood tests)',
      'Ultrasound dating scan (Weeks 8–12)',
      'Nuchal translucency screening (Weeks 11–13)',
      'Blood pressure and weight baseline',
    ],
    emotionalNote:
        'It\'s completely normal to feel overwhelmed, anxious, or even unsure. Your feelings are valid. Share them with someone you trust — or with your midwife.',
  ),
  _TrimesterData(
    name: 'Second Trimester',
    weeks: 'Weeks 14 – 27',
    icon: Icons.monitor_heart_outlined,
    headline: 'The golden period of pregnancy',
    summary:
        'Most people feel much better in the second trimester. Morning sickness often fades, energy returns, and you\'ll begin to feel your baby move for the first time.',
    babyDevelopment: [
      'Week 14 – Baby can make facial expressions',
      'Week 16 – Eyes can move; tiny eyebrows forming',
      'Week 18 – Yawning, hiccupping, and swallowing amniotic fluid',
      'Week 20 – You may feel first movements',
      'Week 22 – Lips, eyelids, and eyebrows clearly visible',
      'Week 26 – Eyes begin to open and respond to sound',
      'Week 27 – Brain developing rapidly and the baby gains more strength',
    ],
    motherChanges: [
      'Baby bump becomes visible',
      'Skin may stretch; stretch marks may appear',
      'Back pain begins as posture shifts',
      'Braxton Hicks contractions may start',
      'Increased appetite and food cravings',
      'Nasal congestion (pregnancy rhinitis)',
    ],
    commonSymptoms: [
      _Symptom('Back pain', 'Use a pregnancy pillow; avoid heavy lifting.',
          Icons.accessibility_new),
      _Symptom(
          'Round ligament pain',
          'Sharp pain on lower belly sides — normal. Move slowly.',
          Icons.healing_outlined),
      _Symptom('Heartburn', 'Eat smaller meals; avoid spicy and acidic foods.',
          Icons.local_fire_department_outlined),
      _Symptom('Leg cramps', 'Stay hydrated; stretch calves before bed.',
          Icons.directions_walk),
      _Symptom('Stretch marks', 'Moisturize daily with oil or lotion.',
          Icons.spa_outlined),
    ],
    checklistItems: [
      _ChecklistItem('Schedule anatomy scan (Week 18–20)', urgent: true),
      _ChecklistItem('Discuss gestational diabetes screening'),
      _ChecklistItem('Start shopping for maternity clothes'),
      _ChecklistItem('Begin researching childbirth classes'),
      _ChecklistItem('Plan your birth plan preferences'),
      _ChecklistItem('Set up emergency contact list'),
      _ChecklistItem('Discuss hospital or birthing center choice'),
    ],
    nutritionTips: [
      _NutritionTip('Omega-3 (fish, chia seeds)',
          'Supports baby\'s brain development', Icons.egg),
      _NutritionTip(
          'Vitamin D (eggs, sunlight)', 'Supports bone health', Icons.wb_sunny),
      _NutritionTip('Protein (chicken, legumes)',
          'Supports tissue and muscle growth', Icons.restaurant),
      _NutritionTip('Fiber (oats, vegetables)', 'Helps prevent constipation',
          Icons.grass),
      _NutritionTip('Magnesium (nuts, seeds)', 'May reduce leg cramps',
          Icons.local_dining),
    ],
    warningSigns: [
      _WarningSigns('Preterm labor contractions before Week 37',
          isEmergency: true),
      _WarningSigns('Sudden swelling of face or hands', isEmergency: true),
      _WarningSigns('Decreased or no fetal movement'),
      _WarningSigns('Severe headaches or vision changes'),
      _WarningSigns('Signs of urinary tract infection'),
    ],
    medicalVisits: [
      'Anatomy ultrasound scan (Weeks 18–20)',
      'Gestational diabetes screening (Weeks 24–28)',
      'Regular blood pressure monitoring',
      'Iron levels and anemia check',
    ],
    emotionalNote:
        'Many mothers feel a surge of connection as they feel their baby move. It\'s also normal to feel anxious about the changes ahead. Take it one day at a time.',
  ),
  _TrimesterData(
    name: 'Third Trimester',
    weeks: 'Weeks 28 – 40+',
    icon: Icons.baby_changing_station_outlined,
    headline: 'Almost there — prepare to meet your baby',
    summary:
        'The final stretch. Your baby is gaining weight and preparing for life outside the womb, and your body is getting ready for labor and delivery.',
    babyDevelopment: [
      'Week 28 – Bone marrow produces red blood cells',
      'Week 30 – Brain developing billions of neurons',
      'Week 32 – Practices breathing movements and gains fat',
      'Week 35 – Kidneys fully developed; most organs ready',
      'Week 36 – Baby is considered early term',
      'Week 38 – Considered full term and ready for delivery',
      'Week 40 – Average due date and baby continues gaining strength',
    ],
    motherChanges: [
      'Difficulty sleeping due to baby\'s size',
      'Frequent urination returns as baby presses bladder',
      'Shortness of breath as uterus pushes up',
      'Braxton Hicks contractions may become more noticeable',
      'Pelvic pressure as baby drops lower',
      'Colostrum may leak from breasts',
    ],
    commonSymptoms: [
      _Symptom(
          'Insomnia',
          'Use a pregnancy pillow and sleep on your left side.',
          Icons.nightlight_outlined),
      _Symptom(
          'Swollen ankles',
          'Elevate feet; avoid standing for long periods.',
          Icons.airline_seat_legroom_extra),
      _Symptom(
          'Pelvic pain',
          'Wear a support belt and avoid stairs when possible.',
          Icons.health_and_safety_outlined),
      _Symptom(
          'Braxton Hicks',
          'Drink water and change positions. Not real labor.',
          Icons.favorite_border),
      _Symptom('Shortness of breath',
          'Sleep slightly propped up; avoid overexertion.', Icons.air_outlined),
    ],
    checklistItems: [
      _ChecklistItem('Pack your hospital bag', urgent: true),
      _ChecklistItem('Finalize birth plan with midwife', urgent: true),
      _ChecklistItem('Install and test baby car seat'),
      _ChecklistItem('Prepare the nursery or baby space'),
      _ChecklistItem('Learn signs of true versus false labor'),
      _ChecklistItem('Arrange postpartum help at home'),
      _ChecklistItem('Stock up on postpartum supplies'),
    ],
    nutritionTips: [
      _NutritionTip(
          'Iron (spinach, red meat)',
          'Prepare for blood loss during delivery',
          Icons.health_and_safety_outlined),
      _NutritionTip(
          'Vitamin K (broccoli, eggs)', 'Supports blood clotting', Icons.egg),
      _NutritionTip('Dates (6/day from Week 36)',
          'May support cervical ripening', Icons.inventory_2),
      _NutritionTip('Collagen (bone broth)',
          'Supports tissue repair postpartum', Icons.ramen_dining),
      _NutritionTip(
          'Hydration',
          'Helps prevent Braxton Hicks and supports circulation',
          Icons.opacity),
    ],
    warningSigns: [
      _WarningSigns('Regular contractions before Week 37', isEmergency: true),
      _WarningSigns('Water breaking with gush or trickle', isEmergency: true),
      _WarningSigns('Baby not moving for 12+ hours', isEmergency: true),
      _WarningSigns('Severe headache with vision changes', isEmergency: true),
      _WarningSigns('Bleeding heavier than spotting', isEmergency: true),
    ],
    medicalVisits: [
      'Biweekly checkups from Week 28–36',
      'Weekly checkups from Week 36 onward',
      'Group B Streptococcus (GBS) test (Week 35–37)',
      'Non-stress test if high-risk or overdue',
    ],
    emotionalNote:
        'Anticipation, excitement, and fear are all normal. Talk to your midwife about your birth preferences and fears. You are stronger than you know.',
  ),
];

const _weeklyFacts = <int, String>{
  4: 'Your baby is the size of a poppy seed.',
  5: 'Heart is beginning to form.',
  6: 'Heartbeat detectable by ultrasound.',
  7: 'Brain growing quickly.',
  8: 'All major organs are forming.',
  9: 'Fingers and toes are defined.',
  10: 'Baby can move, but you cannot feel it yet.',
  11: 'Tooth buds are forming under gums.',
  12: 'Baby can yawn and hiccup.',
  13: 'Fingerprints are unique to your baby.',
  14: 'Baby can make facial expressions.',
  15: 'Skeleton is changing from cartilage to bone.',
  16: 'Eyes slowly moving beneath fused eyelids.',
  17: 'Baby can hear your voice.',
  18: 'You may feel first flutters this week.',
  19: 'Protective coating forms on baby skin.',
  20: 'Halfway there! Baby is about 25 cm long.',
  21: 'Baby sleeps and wakes in cycles.',
  22: 'Lips, eyelids, and eyebrows are visible.',
  23: 'Sense of movement is developed.',
  24: 'Lungs are developing air sacs.',
  25: 'Baby responds to your touch.',
  26: 'Eyes begin to open for the first time.',
  27: 'Brain is developing rapidly.',
  28: 'Bone marrow is producing red blood cells.',
  29: 'Muscles and lungs are maturing.',
  30: 'Baby gains more weight each week.',
  31: 'All five senses are functioning.',
  32: 'Baby is practicing breathing movements.',
  33: 'Skull bones remain soft and flexible for birth.',
  34: 'Fingernails reach the tips of the fingers.',
  35: 'Kidneys are fully developed and organs are ready.',
  36: 'Early term — baby could arrive any day.',
  37: 'Full term — the baby is ready for the world.',
  38: 'Your baby is fully developed.',
  39: 'Baby continues to gain weight steadily.',
  40: 'Due date week — baby may arrive soon.',
};

// ============================================
// FILIPINO TRANSLATIONS (Complete coverage)
// ============================================

const _trimesterNameFilipino = [
  'Unang Trimester',
  'Ikalawang Trimester',
  'Ikatlong Trimester',
];

const _trimesterHeadlineFilipino = [
  'Nagsisimula pa lamang ang iyong sanggol!',
  'Ang ginintuang yugto ng pagbubuntis',
  'Malapit nang dumating — maghanda na sa iyong baby',
];

const _trimesterSummaryFilipino = [
  'Ang unang trimester ay panahon ng kamangha-manghang pagbabago. Ang iyong katawan ay nagpupunyagi upang bumuo ng buhay, at ang iyong sanggol ay lumalaki mula sa isang maliit na selula tungo sa isang maliit na tao na may pintig ng puso.',
  'Kadalasan, mas magaan ang pakiramdam sa ikalawang trimester. Bumabawas ang morning sickness, bumabalik ang iyong enerhiya, at mararamdaman mo na ang mga paggalaw ng sanggol.',
  'Ang huling bahagi ng pagbubuntis. Tumitimbang ang iyong sanggol at naghahanda na para sa paglabas, habang ang iyong katawan ay inihahanda ang sarili para sa labor at delivery.',
];

const _trimesterNoteFilipino = [
  'Normal lamang na makaramdam ng pagod, pag-aalala, o pagkalito. Valid ang iyong nararamdaman. Ibahagi ito sa taong pinagkakatiwalaan mo o sa iyong midwife.',
  'Maraming ina ang nakakaramdam ng koneksyon sa paggalaw ng sanggol. Normal din ang kaba tungkol sa pagbabago. Isang hakbang lamang bawat araw.',
  'Normal ang halo-halong damdamin ng excitement at takot. Ipaalam sa iyong midwife ang iyong mga plano at mga pangamba. Mas malakas ka kaysa sa inaakala mo.',
];

const _weeklyFactsFilipino = <int, String>{
  4: 'Kasing laki ng buto ng poppy ang iyong sanggol.',
  5: 'Nagsisimulang mabuo ang puso.',
  6: 'Maaaring marinig ang tibok ng puso sa ultrasound.',
  7: 'Mabilis na lumalaki ang utak.',
  8: 'Ang lahat ng pangunahing organ ay nabubuo.',
  9: 'Dahan-dahang lumilitaw ang mga daliri at daliri sa paa.',
  10: 'Nakakagalaw ang sanggol, pero hindi mo pa nararamdaman.',
  11: 'Nabubuo ang mga ngipin sa ilalim ng gilagid.',
  12: 'Nakakagawa ng hikab at pag-ubo ang sanggol.',
  13: 'Natatangi ang fingerprints ng iyong baby.',
  14: 'Nakagagawa ng ekspresyon sa mukha ang sanggol.',
  15: 'Naglilipat ang skeletong kartilago tungo sa buto.',
  16: 'Dahan-dahang kumikilos ang mga mata sa ilalim ng fused eyelids.',
  17: 'Naririnig ng sanggol ang iyong boses.',
  18: 'Maaring maramdaman mo ang unang kumikindat ngayong linggo.',
  19: 'Nabubuo ang proteksiyon na balat ng sanggol.',
  20: 'Kalahati na! Mga 25 cm na ang haba ng sanggol.',
  21: 'Natutulog at nagigising sa mga cycle ang sanggol.',
  22: 'Maliwanag na makikita ang labi, talukap, at kilay.',
  23: 'Nade-develop na ang sense of movement.',
  24: 'Nade-develop ang mga baga at air sacs.',
  25: 'Tumutugon ang sanggol sa iyong paghipo.',
  26: 'Nagsisimulang bumukas ang mata ng sanggol.',
  27: 'Mabilis na lumalaki ang utak.',
  28: 'Gumagawa na ng pulang selula ng dugo ang bone marrow.',
  29: 'Nagmumuni-muni ang mga kalamnan at baga.',
  30: 'Lumalakas ang timbang ng sanggol bawat linggo.',
  31: 'Gumagana na ang lahat ng limang pandama.',
  32: 'Nagsasanay maghinga ang sanggol.',
  33: 'Lumanay ang buto ng bungo para sa kapanganakan.',
  34: 'Umaabot na sa dulo ng daliri ang mga kuko.',
  35: 'Ganap na nabubuo ang mga bato at iba pang organo.',
  36: 'Maaaring dumating ang sanggol anumang araw.',
  37: 'Nasa full term na ang sanggol at handa nang lumabas.',
  38: 'Buong-buo na ang iyong baby.',
  39: 'Patuloy ang pagdagdag ng timbang ng sanggol.',
  40: 'Linggo ng due date — malapit na ang pagdating.',
};

// Comprehensive translation map (complete coverage for all used strings)
const _contentTranslationsFilipino = {
  // Baby Development
  'Week 4 – Embryo implants; neural tube begins forming':
      'Linggo 4 – Na-i-implant ang embryo; nagsisimula ang neural tube.',
  'Week 6 – Heart starts beating': 'Linggo 6 – Nagsisimulang tumibok ang puso.',
  'Week 8 – All major organs are forming; fingers and toes appear':
      'Linggo 8 – Nabubuo ang lahat ng pangunahing organo; lumilitaw ang mga daliri sa kamay at paa.',
  'Week 10 – Baby can move, though you can\'t feel it yet':
      'Linggo 10 – Nakakagalaw na ang sanggol, ngunit hindi mo pa ito nararamdaman.',
  'Week 12 – Kidneys produce urine; baby can yawn and hiccup':
      'Linggo 12 – Gumagawa ng ihi ang mga bato; nakakabuka at nakakakuha ng hikab ang sanggol.',
  'Week 13 – Fingerprints are forming; the baby continues to grow rapidly':
      'Linggo 13 – Nabubuo na ang fingerprints; patuloy na mabilis ang paglaki ng sanggol.',
  'Week 14 – Baby can make facial expressions':
      'Linggo 14 – Nakakagawa ng ekspresyon sa mukha ang sanggol.',
  'Week 16 – Eyes can move; tiny eyebrows forming':
      'Linggo 16 – Nakakagalaw ang mga mata; nabubuo ang maliliit na kilay.',
  'Week 18 – Yawning, hiccupping, and swallowing amniotic fluid':
      'Linggo 18 – Bumubuka, humihikab, at lumulunok ng amniotic fluid.',
  'Week 20 – You may feel first movements':
      'Linggo 20 – Maaaring maramdaman mo ang unang paggalaw.',
  'Week 22 – Lips, eyelids, and eyebrows clearly visible':
      'Linggo 22 – Kitang-kita na ang labi, talukap ng mata, at kilay.',
  'Week 26 – Eyes begin to open and respond to sound':
      'Linggo 26 – Nagsisimulang bumukas ang mga mata at tumutugon sa tunog.',
  'Week 27 – Brain developing rapidly and the baby gains more strength':
      'Linggo 27 – Mabilis na lumalago ang utak at lumalakas ang sanggol.',
  'Week 28 – Bone marrow produces red blood cells':
      'Linggo 28 – Gumagawa ang bone marrow ng pulang selula ng dugo.',
  'Week 30 – Brain developing billions of neurons':
      'Linggo 30 – Lumalaki ang utak at bumubuo ng bilyon-bilyong neuron.',
  'Week 32 – Practices breathing movements and gains fat':
      'Linggo 32 – Nagsasanay ng paghinga at nadadagdagan ang taba.',
  'Week 35 – Kidneys fully developed; most organs ready':
      'Linggo 35 – Ganap na nabuo ang mga bato; handa na ang karamihan sa mga organo.',
  'Week 36 – Baby is considered early term':
      'Linggo 36 – Itinuturing na early term ang sanggol.',
  'Week 38 – Considered full term and ready for delivery':
      'Linggo 38 – Itinuturing na full term at handa nang ipanganak.',
  'Week 40 – Average due date and baby continues gaining strength':
      'Linggo 40 – Karaniwang araw ng due date at patuloy ang pagdagdag ng lakas ng sanggol.',

  // Nutrition
  'Folic acid (leafy greens)': 'Folic acid (mga dahong gulay)',
  'Prevents neural tube defects': 'Nagiiwas sa depekto sa neural tube',
  'Iron (red meat, beans)': 'Iron (pulang karne, beans)',
  'Supports baby\'s blood supply': 'Sumusuporta sa dugo ng sanggol',
  'Calcium (dairy, tofu)': 'Calcium (gatas, tofu)',
  'Builds bones and teeth': 'Nagpapalakas ng buto at ngipin',
  'Vitamin B6 (bananas)': 'Vitamin B6 (saging)',
  'Reduces nausea and supports energy':
      'Nagpapabawas ng pagduduwal at sumusuporta sa enerhiya',
  'Water (8+ glasses/day)': 'Tubig (8+ baso/araw)',
  'Prevents dehydration and UTIs': 'Nagiiwas sa dehydration at UTI',
  'Omega-3 (fish, chia seeds)': 'Omega-3 (isda, chia seeds)',
  'Supports baby\'s brain development':
      'Sumusuporta sa pag-unlad ng utak ng sanggol',
  'Vitamin D (eggs, sunlight)': 'Vitamin D (itlog, sikat ng araw)',
  'Supports bone health': 'Sumusuporta sa kalusugan ng buto',
  'Protein (chicken, legumes)': 'Protein (manok, legumes)',
  'Supports tissue and muscle growth':
      'Sumusuporta sa paglaki ng tisyu at kalamnan',
  'Fiber (oats, vegetables)': 'Fiber (oats, gulay)',
  'Helps prevent constipation': 'Nakakatulong umiwas sa constipation',
  'Magnesium (nuts, seeds)': 'Magnesium (mani, buto)',
  'May reduce leg cramps': 'Maaaring magpabawas ng pulikat sa binti',
  'Iron (spinach, red meat)': 'Iron (spinach, pulang karne)',
  'Prepare for blood loss during delivery':
      'Ihanda ang katawan para sa pagdurugo sa panganganak',
  'Vitamin K (broccoli, eggs)': 'Vitamin K (brokoli, itlog)',
  'Supports blood clotting': 'Sumusuporta sa pamumuo ng dugo',
  'Dates (6/day from Week 36)': 'Dates (6/araw mula Linggo 36)',
  'May support cervical ripening': 'Maaaring sumuporta sa paghinog ng cervix',
  'Collagen (bone broth)': 'Collagen (sabaw ng buto)',
  'Supports tissue repair postpartum':
      'Sumusuporta sa pag-ayos ng tisyu pagkatapos manganak',
  'Hydration': 'Pag-inom ng sapat na tubig',
  'Helps prevent Braxton Hicks and supports circulation':
      'Nakakatulong maiwasan ang Braxton Hicks at sumusuporta sa daloy ng dugo',

  // Checklist
  'Schedule first prenatal checkup': 'Mag-iskedyul ng unang prenatal checkup',
  'Start prenatal vitamins with folic acid':
      'Simulan ang prenatal vitamins na may folic acid',
  'Avoid alcohol, smoking, and raw foods':
      'Iwasan ang alak, paninigarilyo, at hilaw na pagkain',
  'Inform your midwife of all medications':
      'Ipagbigay-alam sa iyong midwife ang lahat ng gamot',
  'Morning sickness': 'Pagkakasuka sa umaga',
  'Eat small, frequent meals. Ginger tea helps.':
      'Kumain ng maliit at madalas. Nakakatulong ang ginger tea.',
  'Fatigue': 'Pagkapagod',
  'Rest as much as possible. Short naps are fine.':
      'Magpahinga nang sapat hangga\'t maaari. Ayos lang ang maiikling tulog.',
  'Food aversions': 'Pag-ayaw sa pagkain',
  'Eat what you can tolerate. Bland foods often work.':
      'Kumain ng kaya mong tiisin. Madalas na epektibo ang mga bland na pagkain.',
  'Mood swings': 'Pagbabago ng mood',
  'Hormones are shifting. Journaling can help.':
      'Nagbabago ang hormones. Makakatulong ang pag-journal.',
  'Bloating': 'Panunumpa',
  'Avoid gas-producing foods; eat slowly.':
      'Iwasan ang mga pagkain na nagdudulot ng hangin; kumain nang dahan-dahan.',
  'Back pain': 'Pananakit ng likod',
  'Use a pregnancy pillow; avoid heavy lifting.':
      'Gumamit ng pregnancy pillow; iwasan ang mabibigat na buhat.',
  'Round ligament pain': 'Pananakit ng round ligament',
  'Sharp pain on lower belly sides — normal. Move slowly.':
      'Matalim na sakit sa gilid ng ibabang tiyan — normal ito. Kumilos nang dahan-dahan.',
  'Heartburn': 'Pangangasim ng sikmura',
  'Eat smaller meals; avoid spicy and acidic foods.':
      'Kumain ng mas maliliit na meal; iwasan ang maaanghang at acidic na pagkain.',
  'Leg cramps': 'Pulikat sa binti',
  'Stay hydrated; stretch calves before bed.':
      'Uminom ng sapat na tubig; i-stretch ang binti bago matulog.',
  'Stretch marks': 'Stretch marks',
  'Moisturize daily with oil or lotion.':
      'Maglagay araw-araw ng langis o lotion sa balat.',
  'Back pain begins as posture shifts':
      'Nagsisimula ang pananakit ng likod habang nagbabago ang postura',
  'Get blood type and Rh factor confirmed':
      'Kumpirmahin ang blood type at Rh factor',
  'Discuss genetic screening options':
      'Pag-usapan ang mga opsyon sa genetic screening',
  'Start a pregnancy journal': 'Magsimula ng pregnancy journal',
  'Schedule anatomy scan (Week 18–20)':
      'Mag-iskedyul ng anatomy scan (Linggo 18–20)',
  'Discuss gestational diabetes screening':
      'Pag-usapan ang gestational diabetes screening',
  'Start shopping for maternity clothes':
      'Magsimula nang mamili ng damit-pang-maternity',
  'Begin researching childbirth classes':
      'Magsaliksik tungkol sa mga klase sa panganganak',
  'Plan your birth plan preferences':
      'Planuhin ang iyong birth plan preferences',
  'Set up emergency contact list': 'Ihanda ang listahan ng emergency contact',
  'Discuss hospital or birthing center choice':
      'Pag-usapan ang pagpili ng ospital o birthing center',
  'Install and test baby car seat': 'I-install at subukan ang baby car seat',
  'Prepare the nursery or baby space':
      'Ihanda ang nursery o espasyo ng sanggol',
  'Learn signs of true versus false labor':
      'Alamin ang mga palatandaan ng tunay at hindi tunay na labor',
  'Arrange postpartum help at home': 'Ayusin ang postpartum na tulong sa bahay',
  'Stock up on postpartum supplies':
      'Mag-stock ng mga gamit para sa postpartum',
  'Pack your hospital bag': 'I-empake ang iyong hospital bag',
  'Finalize birth plan with midwife':
      'Tapusin ang birth plan kasama ang midwife',

  // Hospital bag items
  'Government-issued ID and PhilHealth card':
      'Government-issued ID at PhilHealth card',
  'Maternity card or prenatal records': 'Maternity card o prenatal records',
  'Comfortable loose clothing and slippers':
      'Komportableng maluwag na damit at tsinelas',
  'Newborn onesies, blanket, and diapers':
      'Mga onesies ng bagong silang, kumot, at lampin',
  'Toiletries for you and baby': 'Toiletries para sa iyo at sa baby',
  'Snacks and drinks for labor': 'Meryenda at inumin para sa labor',
  'Phone charger': 'Phone charger',
  'Cash for hospital fees': 'Cash para sa bayarin sa ospital',

  // Warning signs
  'Heavy vaginal bleeding': 'Malakas na pagdurugo mula sa ari',
  'Severe abdominal pain': 'Matinding pananakit ng tiyan',
  'High fever above 38°C': 'Mataas na lagnat higit sa 38°C',
  'Painful or burning urination': 'Masakit o nasusunog na pag-ihi',
  'Signs of depression or anxiety': 'Palatandaan ng depression o anxiety',
  'Preterm labor contractions before Week 37':
      'Pagkakaroon ng kontraksiyon bago ang Linggo 37',
  'Sudden swelling of face or hands': 'Biglaang pamamaga ng mukha o kamay',
  'Decreased or no fetal movement': 'Bawas o walang paggalaw ng sanggol',
  'Severe headaches or vision changes':
      'Matinding sakit ng ulo o pagbabago sa paningin',
  'Signs of urinary tract infection': 'Palatandaan ng impeksyon sa ihi',
  'Regular contractions before Week 37':
      'Regular na kontraksiyon bago ang Linggo 37',
  'Water breaking with gush or trickle':
      'Pagputok ng tubig na may umagos o tumutulo',
  'Baby not moving for 12+ hours':
      'Hindi gumagalaw ang sanggol ng higit sa 12 oras',
  'Severe headache with vision changes':
      'Matinding sakit ng ulo na may pagbabago sa paningin',
  'Bleeding heavier than spotting': 'Pagdurugo na mas malakas kaysa spotting',

  // Food to avoid
  'Raw or undercooked meat and eggs':
      'Hilaw o hindi lutong lubos na karne at itlog',
  'High-mercury fish such as shark and swordfish':
      'Isdang mataas sa mercury tulad ng pating at espadon',
  'Unpasteurized dairy and soft cheeses':
      'Gatas na hindi pasteurized at malambot na keso',
  'Alcohol of any kind': 'Alak ng anumang uri',
  'Excess caffeine (limit to 200mg/day)':
      'Sobra sa caffeine (limitahan sa 200mg/bawat araw)',
  'Processed junk food and excess sugar':
      'Pinrosesong junk food at labis na asukal',

  // Medical visits
  'First prenatal visit (confirm pregnancy, blood tests)':
      'Unang prenatal visit (kumpirmasyon ng pagbubuntis, blood tests)',
  'Ultrasound dating scan (Weeks 8–12)': 'Ultrasound dating scan (Linggo 8–12)',
  'Nuchal translucency screening (Weeks 11–13)':
      'Nuchal translucency screening (Linggo 11–13)',
  'Blood pressure and weight baseline': 'Blood pressure at weight baseline',
  'Anatomy ultrasound scan (Weeks 18–20)':
      'Anatomy ultrasound scan (Linggo 18–20)',
  'Gestational diabetes screening (Weeks 24–28)':
      'Gestational diabetes screening (Linggo 24–28)',
  'Regular blood pressure monitoring': 'Regular na blood pressure monitoring',
  'Iron levels and anemia check': 'Pagsusuri ng iron levels at anemia',
  'Biweekly checkups from Week 28–36':
      'Checkup kada dalawang linggo mula Linggo 28–36',
  'Weekly checkups from Week 36 onward': 'Checkup linggu-linggo mula Linggo 36',
  'Group B Streptococcus (GBS) test (Week 35–37)':
      'Group B Streptococcus (GBS) test (Linggo 35–37)',
  'Non-stress test if high-risk or overdue':
      'Non-stress test kung high-risk o overdue',

  // UI Labels
  'Go to the hospital immediately': 'Agad na pumunta sa ospital',
  'Watch and monitor': 'Bantayan at subaybayan',
  'Pregnancy Progress': 'Progreso ng Pagbubuntis',
  'Overview': 'Pangkalahatan',
  'Baby': 'Sanggol',
  'Symptoms': 'Sintomas',
  'Nutrition': 'Nutrisyon',
  'Checklist': 'Checklist',
  'Warnings': 'Babala',
  'THIS WEEK': 'NGAYONG LINGGO',
  'A Note for You': 'Tandaan Para sa Iyo',
  'Trimester Journey': 'Paglalakbay ng Trimester',
  'Medical Visits This Trimester': 'Mga Medikal na Pagbisita ngayong Trimester',
  'Development Milestones': 'Mga Milestone ng Pag-unlad',
  'Changes in Your Body': 'Mga Pagbabago sa Iyong Katawan',
  'Key Nutrients This Trimester': 'Pangunahing Nutrisyon ngayong Trimester',
  'Foods to Avoid': 'Mga Pagkaing Iwasan',
  'Eating for Two': 'Pagkain para sa Dalawa',
  'Priority Tasks': 'Pangunahing Gawain',
  'When You Can': 'Kapag Maaari',
  'Hospital Bag Essentials': 'Mga Kailangan sa Bag ng Ospital',
  'Emergency Contacts': 'Mga Emergency na Kontak',
  'Daily kick count': 'Araw-araw na bilang ng sipa',
  'Baby this week': 'Sanggol ngayong linggo',
  'Size': 'Sukat',
  'Weight': 'Timbang',
  'Baby Size': 'Sukat ng Sanggol',
  'Baby Weight': 'Timbang ng Sanggol',
  'Due Date': 'Araw ng Pagbubuntis',
  'Weeks Left': 'Natitirang Linggo',
  'Risk Level': 'Antas ng Panganib',
  'Fetal Count': 'Bilang ng Sanggol',
  'Prenatal Risk Summary': 'Buod ng Panganib',
  'Risk Factors': 'Mga Salik ng Panganib',
  'Recommended Actions': 'Rinerekomendang Hakbang',
  'NOW': 'NGAYON',
  'YOU ARE HERE': 'NANDITO KA',

  // Dynamic translations
  '1 baby': '1 sanggol',
  'babies': 'mga sanggol',
  'weeks': 'linggo',
  'w left': 'natitirang linggo',
};

/// Safely translate content with fallback
String _translateContent(String text, AppLanguage language) {
  if (language != AppLanguage.filipino) return text;

  // Try exact match first
  if (_contentTranslationsFilipino.containsKey(text)) {
    return _contentTranslationsFilipino[text]!;
  }

  // Try case-insensitive match
  final lowerText = text.toLowerCase();
  for (final entry in _contentTranslationsFilipino.entries) {
    if (entry.key.toLowerCase() == lowerText) {
      return entry.value;
    }
  }

  return text;
}

// ============================================
// MAIN WIDGET
// ============================================

class PregnancyDetailPage extends StatefulWidget {
  final int week;
  final String trimester;
  final String dueDate;
  final int weeksLeft;
  final String babySize;
  final String babyWeight;
  final String firstName;
  final String riskLevel;
  final int fetalCount;
  final int pregnancyId; // Added to fetch personalized data
  final List<String>? riskFactors;
  final List<String>? suggestedActions;

  const PregnancyDetailPage({
    super.key,
    required this.week,
    required this.trimester,
    required this.dueDate,
    required this.weeksLeft,
    required this.babySize,
    required this.babyWeight,
    required this.firstName,
    required this.riskLevel,
    required this.fetalCount,
    required this.pregnancyId,
    this.riskFactors,
    this.suggestedActions,
  });

  @override
  State<PregnancyDetailPage> createState() => _PregnancyDetailPageState();
}

class _PregnancyDetailPageState extends State<PregnancyDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _TrimesterData _data;

  // Personalized data from database
  List<String> _personalizedSymptoms = [];
  List<String> _personalizedWarnings = [];
  List<String> _personalizedActions = [];
  bool _isLoadingPersonalized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _data = _trimesterForWeek(widget.week);
    _loadPersonalizedData();
  }

  Future<void> _loadPersonalizedData() async {
    setState(() => _isLoadingPersonalized = true);

    try {
      final supabase = SupabaseService.client;

      // Fetch actual symptoms from database
      final List<dynamic>? symptomsData = await supabase
          .from('pregnancy_symptoms')
          .select('symptom_type_id, symptom_types(symptom_name, risk_category)')
          .eq('pregnancy_id', widget.pregnancyId) as List<dynamic>?;

      if (symptomsData != null) {
        _personalizedSymptoms = symptomsData
            .where((s) => s['symptom_types'] != null)
            .map((s) => s['symptom_types']['symptom_name'] as String)
            .toList();
      }

      // Fetch risk assessment
      final riskData = await supabase
          .from('pregnancy_risk_assessments')
          .select('pregnancy_risk_id, risk_level')
          .eq('pregnancy_id', widget.pregnancyId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (riskData != null) {
        final riskId = riskData['pregnancy_risk_id'];

        // Fetch risk factors
        final List<dynamic>? factorsData = await supabase
            .from('pregnancy_risk_factors')
            .select('factor')
            .eq('pregnancy_risk_id', riskId) as List<dynamic>?;

        if (factorsData != null) {
          _personalizedWarnings =
              factorsData.map((f) => f['factor'] as String).toList();
        }
      }

      // Fetch AI-generated recommendations
      final aiData = await supabase
          .from('ai_responses')
          .select('response')
          .eq('reference_table', 'pregnancies')
          .eq('reference_id', widget.pregnancyId)
          .eq('response_type', 'recommendation')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (aiData != null && aiData['response'] is String) {
        // Parse AI response into actionable items
        final response = aiData['response'] as String;
        _personalizedActions = response
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) =>
                line.replaceAll(RegExp(r'^[\d\-\.\*]+\s*'), '').trim())
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading personalized data: $e');
    }

    if (mounted) {
      setState(() => _isLoadingPersonalized = false);
    }
  }

  _TrimesterData _trimesterForWeek(int week) {
    if (week <= 13) return _trimesterContent[0];
    if (week <= 27) return _trimesterContent[1];
    return _trimesterContent[2];
  }

  int _trimesterIndexForWeek(int week) {
    if (week <= 13) return 0;
    if (week <= 27) return 1;
    return 2;
  }

  Color _riskColor(String riskLevel) {
    final normalized = riskLevel.toLowerCase().trim();
    if (normalized == 'high') return AppColors.error;
    if (normalized == 'medium') return AppColors.warning;
    return AppColors.success;
  }

  String _translate(String english, String filipino, AppLanguage language) {
    return language == AppLanguage.filipino ? filipino : english;
  }

  String _localizedTrimesterName(int index, AppLanguage language) {
    return language == AppLanguage.filipino
        ? _trimesterNameFilipino[index]
        : _trimesterContent[index].name;
  }

  String _localizedFetalCount(int count, AppLanguage language) {
    if (language == AppLanguage.filipino) {
      return count > 1 ? '$count na sanggol' : '1 sanggol';
    }
    return count > 1 ? '$count babies' : '1 baby';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.selectedLanguage,
      builder: (context, language, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerScrolled) => [
              _buildSliverHeader(language),
            ],
            body: Column(
              children: [
                _buildTabBar(language),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(language),
                      _buildBabyTab(language),
                      _buildSymptomsTab(language),
                      _buildNutritionTab(language),
                      _buildChecklistTab(language),
                      _buildWarningsTab(language),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverHeader(AppLanguage language) {
    final trimesterIndex = _trimesterIndexForWeek(widget.week);
    return SliverAppBar(
      expandedHeight: 210,
      collapsedHeight: 70,
      pinned: true,
      backgroundColor: AppColors.brandPrimary,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textOnColor),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final isCollapsed =
              constraints.maxHeight <= topPadding + kToolbarHeight + 16;

          return FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1 : 0,
              child: Text(
                '${_translate('Week', 'Linggo', language)} ${widget.week} • ${_localizedTrimesterName(trimesterIndex, language)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textOnColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            background: Container(
              color: AppColors.brandPrimary,
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_data.icon,
                            color: AppColors.brandPrimary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_translate('Week', 'Linggo', language)} ${widget.week}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textOnColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.firstName.isNotEmpty
                                  ? '${_localizedTrimesterName(trimesterIndex, language)}, ${widget.firstName}'
                                  : _localizedTrimesterName(
                                      trimesterIndex, language),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textOnColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _data.weeks,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textOnColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildProgressBar(language),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(AppLanguage language) {
    final progress = (widget.week / 40).clamp(0.0, 1.0);
    final weeksLeftLabel = _translate('w left', 'natitirang linggo', language);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                _translate(
                    'Pregnancy Progress', 'Progreso ng Pagbubuntis', language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textOnColor,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${(progress * 100).round()}% • ${widget.weeksLeft} $weeksLeftLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppColors.textOnColor,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.textOnColor.withValues(alpha: 0.2),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.textOnColor),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(AppLanguage language) {
    final tabs = [
      _translate('Overview', 'Pangkalahatan', language),
      _translate('Baby', 'Sanggol', language),
      _translate('Symptoms', 'Sintomas', language),
      _translate('Nutrition', 'Nutrisyon', language),
      _translate('Checklist', 'Checklist', language),
      _translate('Warnings', 'Babala', language),
    ];

    return Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.brandPrimary,
        dividerColor: AppColors.borderPrimary.withValues(alpha: 0.6),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorWeight: 3,
        labelPadding: const EdgeInsets.symmetric(horizontal: 18),
        labelColor: AppColors.brandPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        tabs: tabs.map((label) => Tab(text: label, height: 48)).toList(),
      ),
    );
  }

  Widget _buildOverviewTab(AppLanguage language) {
    final weeklyFact = language == AppLanguage.filipino
        ? _weeklyFactsFilipino[widget.week] ??
            'Ang iyong sanggol ay lumalago nang malakas ngayong linggo.'
        : _weeklyFacts[widget.week] ?? 'Your baby is growing strong this week.';
    final trimesterIndex = _trimesterIndexForWeek(widget.week);
    final headline = language == AppLanguage.filipino
        ? _trimesterHeadlineFilipino[trimesterIndex]
        : _data.headline;
    final summary = language == AppLanguage.filipino
        ? _trimesterSummaryFilipino[trimesterIndex]
        : _data.summary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          color: AppColors.bgSecondary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: AppColors.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translate('THIS WEEK', 'NGAYONG LINGGO', language),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      weeklyFact,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _RiskBadge(riskLevel: widget.riskLevel),
                        _FetalBadge(
                          fetalCount: widget.fetalCount,
                          language: language,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildInfoCardsRow(language),
        const SizedBox(height: 14),
        _buildRiskSummaryCard(language),
        const SizedBox(height: 16),
        _buildPersonalizedRecommendations(language),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate(
              'Trimester Journey', 'Paglalakbay ng Trimester', language),
          icon: Icons.timeline,
        ),
        const SizedBox(height: 10),
        _buildTrimesterTimeline(language),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate('Medical Visits This Trimester',
              'Mga Medikal na Pagbisita ngayong Trimester', language),
          icon: Icons.medical_services_outlined,
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: _data.medicalVisits.asMap().entries.map((entry) {
              return _TimelineRow(
                text: _translateContent(entry.value, language),
                isLast: entry.key == _data.medicalVisits.length - 1,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          color: AppColors.brandSecondary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_border,
                    size: 24, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translate(
                          'A Note for You', 'Paalala Para sa Iyo', language),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      language == AppLanguage.filipino
                          ? _trimesterNoteFilipino[trimesterIndex]
                          : _data.emotionalNote,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoCardsRow(AppLanguage language) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SmallInfoBox(
                icon: Icons.straighten,
                title: _translate('Baby Size', 'Sukat ng Sanggol', language),
                value: widget.babySize,
                borderColor: AppColors.borderPrimary,
                iconColor: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SmallInfoBox(
                icon: Icons.monitor_weight_outlined,
                title:
                    _translate('Baby Weight', 'Timbang ng Sanggol', language),
                value: widget.babyWeight,
                borderColor: AppColors.borderPrimary,
                iconColor: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SmallInfoBox(
                icon: Icons.calendar_month_outlined,
                title:
                    _translate('Due Date', 'Araw ng Pagbubuntis', language),
                value: widget.dueDate,
                borderColor: AppColors.borderPrimary,
                iconColor: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SmallInfoBox(
                icon: Icons.timer_outlined,
                title:
                    _translate('Weeks Left', 'Natitirang Linggo', language),
                value:
                    '${widget.weeksLeft} ${_translate('weeks', 'linggo', language)}',
                borderColor: AppColors.borderPrimary,
                iconColor: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SmallInfoBox(
                icon: Icons.health_and_safety_outlined,
                title:
                    _translate('Risk Level', 'Antas ng Panganib', language),
                value: widget.riskLevel.toUpperCase(),
                borderColor: _riskColor(widget.riskLevel),
                iconColor: _riskColor(widget.riskLevel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SmallInfoBox(
                icon: Icons.child_care,
                title:
                    _translate('Fetal Count', 'Bilang ng Sanggol', language),
                value: _localizedFetalCount(widget.fetalCount, language),
                borderColor: AppColors.borderPrimary,
                iconColor: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskSummaryCard(AppLanguage language) {
    final riskLevel = widget.riskLevel.trim();
    final riskFactors = _personalizedWarnings.isNotEmpty
        ? _personalizedWarnings
        : (widget.riskFactors ?? []);
    final badgeColor = _riskColor(riskLevel);

    if (riskLevel.toLowerCase() == 'low' && riskFactors.isEmpty) {
      return _Card(
        color: AppColors.success.withValues(alpha: 0.08),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _translate('Low Risk Pregnancy',
                        'Mababang Panganib na Pagbubuntis', language),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _translate(
                      'Your pregnancy is progressing normally. Continue with regular checkups.',
                      'Maayos ang iyong pagbubuntis. Ipagpatuloy ang regular na checkup.',
                      language,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shield_outlined, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _translate(
                      'Prenatal Risk Summary', 'Buod ng Panganib', language),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              riskLevel.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          if (riskFactors.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _translate('Risk Factors', 'Mga Salik ng Panganib', language),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: riskFactors.map((factor) {
                return _RiskFactorChip(factor: factor);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalizedRecommendations(AppLanguage language) {
    if (_isLoadingPersonalized) {
      return _Card(
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _translate(
                  'Loading personalized recommendations...',
                  'Naglo-load ng personalisadong rekomendasyon...',
                  language,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_personalizedActions.isEmpty) return const SizedBox.shrink();

    return _Card(
      color: AppColors.brandSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.brandPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _translate(
                    'Personalized Recommendations',
                    'Personalisadong Rekomendasyon',
                    language,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._personalizedActions.take(5).map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: AppColors.brandPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTrimesterTimeline(AppLanguage language) {
    const trimesters = [
      ('1st', 'Weeks 1–13', 0),
      ('2nd', 'Weeks 14–27', 1),
      ('3rd', 'Weeks 28–40', 2),
    ];
    final currentIdx = _trimesterIndexForWeek(widget.week);

    return _Card(
      child: Row(
        children: trimesters.asMap().entries.map((entry) {
          final idx = entry.key;
          final trimester = entry.value;
          final isActive = idx == currentIdx;
          final isPast = idx < currentIdx;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.brandPrimary
                              : isPast
                                  ? AppColors.brandPrimary
                                      .withValues(alpha: 0.14)
                                  : AppColors.borderPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            trimester.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isActive
                                  ? AppColors.textOnColor
                                  : isPast
                                      ? AppColors.brandPrimary
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trimester.$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? AppColors.brandPrimary
                              : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _translate('YOU ARE HERE', 'NANDITO KA', language),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (idx < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 32),
                      color: isPast
                          ? AppColors.brandPrimary.withValues(alpha: 0.2)
                          : AppColors.borderPrimary,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBabyTab(AppLanguage language) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          color: AppColors.bgSecondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.child_care,
                  size: 36,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _translate(
                    'Baby this week', 'Sanggol ngayong linggo', language),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _BabyStatChip(
                      label: _translate('Size', 'Sukat', language),
                      value: widget.babySize,
                      icon: Icons.straighten,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BabyStatChip(
                      label: _translate('Weight', 'Timbang', language),
                      value: widget.babyWeight,
                      icon: Icons.monitor_weight_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate(
              'Development Milestones', 'Mga Milestone ng Pag-unlad', language),
          icon: Icons.auto_awesome,
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: _data.babyDevelopment.map((milestone) {
              final isCurrentWeek = milestone.startsWith('Week ${widget.week}');
              return _MilestoneRow(
                text: _translateContent(milestone, language),
                isHighlighted: isCurrentWeek,
                language: language,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate('Changes in Your Body',
              'Mga Pagbabago sa Iyong Katawan', language),
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 10),
        _Card(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _data.motherChanges.map((change) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 64,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderPrimary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle,
                        size: 8, color: AppColors.brandPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _translateContent(change, language),
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Continue with remaining tab builders...
  // (symptoms, nutrition, checklist, warnings tabs are similar to original
  // but with added _translateContent calls and language parameters)

  Widget _buildSymptomsTab(AppLanguage language) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          color: AppColors.bgSecondary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.brandPrimary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _translate(
                    'These are common symptoms for your trimester. Always consult your midwife if you\'re concerned.',
                    'Ito ay mga karaniwang sintomas para sa iyong trimester. Kumunsulta sa iyong midwife kapag nag-aalala ka.',
                    language,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Show personalized symptoms first if available
        if (_personalizedSymptoms.isNotEmpty) ...[
          _SectionHeader(
            title: _translate('Your Reported Symptoms',
                'Iyong Mga Naiulat na Sintomas', language),
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 10),
          ..._personalizedSymptoms.map((symptom) => _SymptomCard(
                symptom: _Symptom(
                  symptom,
                  _translate(
                    'Reported during checkup. Follow your midwife\'s advice.',
                    'Naitala sa checkup. Sundin ang payo ng iyong midwife.',
                    language,
                  ),
                  Icons.medical_services_outlined,
                ),
              )),
          const SizedBox(height: 16),
          _SectionHeader(
            title: _translate('Common Trimester Symptoms',
                'Karaniwang Sintomas ng Trimester', language),
            icon: Icons.list_alt,
          ),
          const SizedBox(height: 10),
        ],
        ..._data.commonSymptoms
            .map((symptom) => _SymptomCard(symptom: symptom)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNutritionTab(AppLanguage language) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          color: AppColors.bgSecondary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: AppColors.brandPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translate(
                          'Eating for Two', 'Pagkain para sa Dalawa', language),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _translate(
                        'You only need about 300 extra calories per day — focus on nutrient-dense, high-quality foods.',
                        'Kailangan mo lamang ng humigit-kumulang 300 dagdag na calories bawat araw — magpokus sa masustansyang pagkain na mataas ang kalidad.',
                        language,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate('Key Nutrients This Trimester',
              'Pangunahing Nutrisyon ngayong Trimester', language),
          icon: Icons.food_bank_outlined,
        ),
        const SizedBox(height: 10),
        ..._data.nutritionTips.map((tip) => _NutritionCard(
              tip: tip,
              language: language,
            )),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate('Foods to Avoid', 'Mga Pagkaing Iwasan', language),
          icon: Icons.block_outlined,
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvoidRow(_translateContent(
                  'Raw or undercooked meat and eggs', language)),
              _AvoidRow(_translateContent(
                  'High-mercury fish such as shark and swordfish', language)),
              _AvoidRow(_translateContent(
                  'Unpasteurized dairy and soft cheeses', language)),
              _AvoidRow(_translateContent('Alcohol of any kind', language)),
              _AvoidRow(_translateContent(
                  'Excess caffeine (limit to 200mg/day)', language)),
              _AvoidRow(_translateContent(
                  'Processed junk food and excess sugar', language)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildChecklistTab(AppLanguage language) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          color: AppColors.bgSecondary,
          child: Row(
            children: [
              const Icon(Icons.checklist_rtl,
                  color: AppColors.brandPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _translate(
                    'Things to do during your current trimester',
                    'Mga dapat gawin sa iyong kasalukuyang trimester',
                    language,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate('Priority Tasks', 'Pangunahing Gawain', language),
          icon: Icons.priority_high,
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: _data.checklistItems
                .where((item) => item.urgent)
                .map((item) => _ChecklistRow(
                      item: item,
                      language: language,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: _translate('When You Can', 'Kapag Maaari', language),
          icon: Icons.event_available_outlined,
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: _data.checklistItems
                .where((item) => !item.urgent)
                .map((item) => _ChecklistRow(
                      item: item,
                      language: language,
                    ))
                .toList(),
          ),
        ),
        if (widget.week >= 28) ...[
          const SizedBox(height: 16),
          _Card(
            color: AppColors.success.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.backpack,
                        color: AppColors.success, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      _translate('Hospital Bag Essentials',
                          'Mga Kailangan sa Bag ng Ospital', language),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._hospitalBagItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _translateContent(item, language),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildWarningsTab(AppLanguage language) {
    final emergencies = _data.warningSigns.where((w) => w.isEmergency).toList();
    final watchFor = _data.warningSigns.where((w) => !w.isEmergency).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency, color: AppColors.error, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _translate('Go to the hospital immediately',
                        'Agad na pumunta sa ospital', language),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...emergencies.map((warning) => _WarningRow(
                    sign: warning,
                    isEmergency: true,
                    language: language,
                  )),
            ],
          ),
        ),
        if (watchFor.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        color: AppColors.warning, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _translate('Watch and monitor', 'Bantayan at subaybayan',
                          language),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.warning,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...watchFor.map((warning) => _WarningRow(
                      sign: warning,
                      isEmergency: false,
                      language: language,
                    )),
              ],
            ),
          ),
        ],
        if (widget.week >= 20) ...[
          const SizedBox(height: 16),
          _Card(
            color: AppColors.bgSecondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translate('Daily kick count', 'Araw-araw na bilang ng sipa',
                      language),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _translate(
                    'Starting around Week 20, count your baby\'s movements once a day. If you feel fewer than 10 movements in 2 hours, contact your midwife.',
                    'Magsimula mga Linggo 20, bilangin ang paggalaw ng iyong sanggol isang beses sa isang araw. Kung makaramdam ka ng mas kaunti sa 10 paggalaw sa loob ng 2 oras, kumunsulta sa iyong midwife.',
                    language,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_in_talk,
                      color: AppColors.brandPrimary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _translate('Emergency Contacts', 'Mga Emergency na Kontak',
                        language),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _translate(
                    'Keep these numbers saved and accessible:',
                    'I-save at gawing madaling maabot ang mga numerong ito:',
                    language),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _emergencyContactItem(_translate(
                  'Nearest hospital emergency room',
                  'Pinakamalapit na emergency room ng ospital',
                  language)),
              _emergencyContactItem(_translate('Your midwife or health center',
                  'Ang iyong midwife o health center', language)),
              _emergencyContactItem(_translate(
                  'Local ambulance or emergency medical transport',
                  'Lokal na ambulansya o emergency medical transport',
                  language)),
              _emergencyContactItem(_translate(
                  'Emergency hotline for your area',
                  'Emergency hotline para sa iyong lugar',
                  language)),
              _emergencyContactItem(_translate(
                  'Trusted family member or partner',
                  'Katiwalaang miyembro ng pamilya o partner',
                  language)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _emergencyContactItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// REUSABLE WIDGETS
// ============================================

class _Card extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _Card({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16, color: AppColors.brandPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String riskLevel;

  const _RiskBadge({required this.riskLevel});

  Color _color() {
    final normalized = riskLevel.toLowerCase().trim();
    if (normalized == 'high') return AppColors.error;
    if (normalized == 'medium') return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        riskLevel.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FetalBadge extends StatelessWidget {
  final int fetalCount;
  final AppLanguage language;

  const _FetalBadge({required this.fetalCount, required this.language});

  @override
  Widget build(BuildContext context) {
    final label = language == AppLanguage.filipino
        ? (fetalCount > 1 ? '$fetalCount na sanggol' : '1 sanggol')
        : (fetalCount > 1 ? '$fetalCount babies' : '1 baby');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }
}

class _RiskFactorChip extends StatelessWidget {
  final String factor;

  const _RiskFactorChip({required this.factor});

  @override
  Widget build(BuildContext context) {
    final isHigh = factor.toLowerCase().contains('high') ||
        factor.toLowerCase().contains('severe') ||
        factor.toLowerCase().contains('emergency');

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 64,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHigh
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHigh
              ? AppColors.error.withValues(alpha: 0.25)
              : AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        factor,
        softWrap: true,
        style: TextStyle(
          fontSize: 12,
          color: isHigh ? AppColors.error : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BabyStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _BabyStatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String text;
  final bool isLast;

  const _TimelineRow({required this.text, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: AppColors.borderPrimary,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  final String text;
  final bool isHighlighted;
  final AppLanguage language;

  const _MilestoneRow({
    required this.text,
    this.isHighlighted = false,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.brandSecondary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.borderPrimary : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isHighlighted ? Icons.star : Icons.circle,
            size: isHighlighted ? 16 : 8,
            color: isHighlighted
                ? AppColors.brandPrimary
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
          if (isHighlighted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _translateStatic('NOW', 'NGAYON', language),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textOnColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _translateStatic(
      String english, String filipino, AppLanguage language) {
    return language == AppLanguage.filipino ? filipino : english;
  }
}

class _SymptomCard extends StatelessWidget {
  final _Symptom symptom;
  const _SymptomCard({required this.symptom});

  @override
  Widget build(BuildContext context) {
    final language = LanguageService.selectedLanguage.value;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(symptom.icon, size: 20, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translateContent(symptom.name, language),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _translateContent(symptom.tip, language),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final _NutritionTip tip;
  final AppLanguage language;

  const _NutritionCard({required this.tip, required this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPrimary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(tip.icon, size: 22, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _translateContent(tip.food, language),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _translateContent(tip.benefit, language),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final _ChecklistItem item;
  final AppLanguage language;

  const _ChecklistRow({required this.item, required this.language});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.urgent ? Icons.priority_high : Icons.radio_button_unchecked,
            size: 18,
            color: item.urgent ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _translateContent(item.task, language),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: item.urgent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final _WarningSigns sign;
  final bool isEmergency;
  final AppLanguage language;

  const _WarningRow({
    required this.sign,
    required this.isEmergency,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEmergency ? Icons.report : Icons.visibility,
            size: 16,
            color: isEmergency ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _translateContent(sign.sign, language),
              style: TextStyle(
                fontSize: 13,
                color: isEmergency ? AppColors.error : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvoidRow extends StatelessWidget {
  final String text;
  const _AvoidRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Static hospital bag items
const _hospitalBagItems = [
  'Government-issued ID and PhilHealth card',
  'Maternity card or prenatal records',
  'Comfortable loose clothing and slippers',
  'Newborn onesies, blanket, and diapers',
  'Toiletries for you and baby',
  'Snacks and drinks for labor',
  'Phone charger',
  'Cash for hospital fees',
];
