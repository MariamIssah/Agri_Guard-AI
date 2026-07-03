"""
AgriGuard Advisory Engine
=========================
Text-based crop disease and stress diagnosis for Ghana smallholder farms.

Usage:
    from advisory_engine import AdvisoryEngine
    engine = AdvisoryEngine()
    diagnosis = engine.diagnose(crop='Maize', region='Ashanti',
                                symptoms='fall armyworm damage, chewed leaves')
    advisory  = engine.generate_advisory(**diagnosis)
"""

from __future__ import annotations
from typing import Optional, Dict, List, Tuple


# ── Crop name normalisation ────────────────────────────────────────────────────

_CROP_ALIASES: Dict[str, str] = {
    'maize': 'Maize', 'corn': 'Maize',
    'rice': 'Rice', 'paddy': 'Rice',
    'cassava': 'Cassava', 'tapioca': 'Cassava',
    'yam': 'Yam',
    'tomato': 'Tomato', 'tomatoes': 'Tomato',
    'pepper': 'Pepper', 'chili': 'Pepper', 'chilli': 'Pepper',
    'cocoa': 'Cocoa', 'cacao': 'Cocoa', 'cocoa beans': 'Cocoa',
    'groundnut': 'Groundnut', 'peanut': 'Groundnut', 'groundnuts': 'Groundnut',
    'soybean': 'Soybean', 'soya': 'Soybean', 'soybeans': 'Soybean',
    'cowpea': 'Cowpea', 'cowpeas': 'Cowpea', 'blackeye': 'Cowpea',
    'millet': 'Millet', 'pearl millet': 'Millet',
    'sorghum': 'Sorghum', 'guinea corn': 'Sorghum',
    'plantain': 'Plantain', 'plaintain': 'Plantain',
    'cocoyam': 'Cocoyam', 'taro': 'Cocoyam',
    'sweet potato': 'Sweet Potato', 'sweetpotato': 'Sweet Potato',
    'okra': 'Okra', 'okro': 'Okra',
    'cabbage': 'Cabbage',
    'onion': 'Onion', 'onions': 'Onion',
    'watermelon': 'Watermelon',
    'sugarcane': 'Sugarcane', 'cane': 'Sugarcane',
    'cotton': 'Cotton',
    'oil palm': 'Oil Palm', 'palm oil': 'Oil Palm',
    'banana': 'Banana',
}


def _normalise_crop(crop: str) -> str:
    if not crop:
        return 'Unknown'
    return _CROP_ALIASES.get(crop.strip().lower(), crop.strip().title())


def _normalise_text(text: Optional[str]) -> str:
    return (text or '').strip().lower()


# ── Symptom → (disease_name, risk_delta) lookup ───────────────────────────────
# Each phrase is matched using substring search on the symptom text.
# risk_delta values are additive; max disease_risk is capped at 1.0.

_SYMPTOM_MAP: List[Tuple[str, float, str]] = [
    # phrase, risk_contribution, disease_hint
    # ── General stress ──────────────────────────────────────────────────────
    ('yellowing',          0.12, 'Nutrient Deficiency / Early Disease'),
    ('yellow leaves',      0.14, 'Yellowing Disease / Viral Infection'),
    ('yellowing leaves',   0.14, 'Yellowing Disease / Viral Infection'),
    ('pale leaves',        0.10, 'Nitrogen Deficiency'),
    ('wilting',            0.18, 'Root Rot / Wilt Disease'),
    ('wilt',               0.16, 'Wilt Disease'),
    ('drooping',           0.12, 'Water Stress / Root Rot'),
    ('stunted',            0.14, 'Viral Infection / Soil Nutrient Deficiency'),
    ('stunted growth',     0.16, 'Viral Infection / Soil Deficiency'),
    ('slow growth',        0.10, 'Nutrient Deficiency'),
    # ── Leaf symptoms ───────────────────────────────────────────────────────
    ('leaf spots',         0.18, 'Fungal Leaf Spot Disease'),
    ('leaf spot',          0.18, 'Fungal Leaf Spot Disease'),
    ('brown spots',        0.16, 'Fungal / Bacterial Leaf Spot'),
    ('dark spots',         0.16, 'Fungal Infection'),
    ('lesions',            0.20, 'Blight / Fungal Disease'),
    ('leaf curl',          0.16, 'Viral Infection / Thrips'),
    ('curling leaves',     0.16, 'Viral Infection / Thrips'),
    ('leaf blight',        0.28, 'Leaf Blight Disease'),
    ('blight',             0.26, 'Blight Disease'),
    ('mottled',            0.20, 'Mosaic Virus'),
    ('mosaic',             0.30, 'Mosaic Virus'),
    ('mottling',           0.20, 'Mosaic Virus'),
    ('streaks',            0.22, 'Streak Virus / Maize Streak Virus'),
    ('streak',             0.22, 'Streak Virus'),
    ('brown leaves',       0.14, 'Late Blight / Rust / Drought Stress'),
    ('brown edges',        0.12, 'Leaf Scorch / Drought Stress'),
    ('dead leaves',        0.18, 'Severe Disease / Drought'),
    ('dry leaves',         0.12, 'Drought / Leaf Scorch'),
    ('necrosis',           0.22, 'Bacterial / Fungal Necrosis'),
    ('necrotic',           0.22, 'Bacterial / Fungal Necrosis'),
    ('chlorosis',          0.14, 'Nutrient Deficiency / Viral Infection'),
    ('powdery',            0.28, 'Powdery Mildew'),
    ('powdery mildew',     0.40, 'Powdery Mildew'),
    ('white coating',      0.24, 'Powdery Mildew'),
    ('white powder',       0.28, 'Powdery Mildew'),
    ('rust',               0.26, 'Rust Disease'),
    ('rust spots',         0.28, 'Rust Disease'),
    ('rusty',              0.24, 'Rust Disease'),
    ('orange spots',       0.22, 'Rust Disease'),
    ('pustules',           0.26, 'Rust Disease'),
    # ── Stem and root ───────────────────────────────────────────────────────
    ('stem rot',           0.30, 'Stem Rot Disease'),
    ('stalk rot',          0.28, 'Stalk Rot'),
    ('root rot',           0.30, 'Root Rot Disease'),
    ('lodging',            0.18, 'Stalk Rot / Wind Damage'),
    ('stem borer',         0.26, 'Stem Borer Infestation'),
    ('borer',              0.24, 'Stem Borer Infestation'),
    ('dead heart',         0.30, 'Stem Borer / Head Borer'),
    ('galls',              0.14, 'Gall Midge / Nematode'),
    ('swelling',           0.12, 'Gall / Bacterial Canker'),
    ('canker',             0.22, 'Bacterial Canker'),
    # ── Fruit and pod ───────────────────────────────────────────────────────
    ('rot',                0.22, 'Fruit / Root Rot Disease'),
    ('fruit rot',          0.28, 'Fruit Rot'),
    ('ear rot',            0.26, 'Ear Rot (Maize)'),
    ('pod rot',            0.26, 'Pod Rot / Black Pod'),
    ('black pod',          0.40, 'Black Pod Disease (Cocoa)'),
    ('pod discolor',       0.20, 'Pod Rot / Black Pod'),
    ('mold',               0.20, 'Mold / Fungal Infection'),
    ('mould',              0.20, 'Mold / Fungal Infection'),
    ('aflatoxin',          0.30, 'Aflatoxin Contamination (Aspergillus)'),
    # ── Pest damage ─────────────────────────────────────────────────────────
    ('armyworm',           0.38, 'Fall Armyworm (Spodoptera frugiperda)'),
    ('fall armyworm',      0.42, 'Fall Armyworm (Spodoptera frugiperda)'),
    ('caterpillar',        0.28, 'Caterpillar / Armyworm Infestation'),
    ('chewed leaves',      0.22, 'Caterpillar / Armyworm Infestation'),
    ('holes in leaves',    0.20, 'Caterpillar / Beetle Damage'),
    ('insect holes',       0.20, 'Insect Infestation'),
    ('insect damage',      0.22, 'Insect Infestation'),
    ('whitefly',           0.22, 'Whitefly Infestation'),
    ('white fly',          0.22, 'Whitefly Infestation'),
    ('aphid',              0.18, 'Aphid Infestation'),
    ('aphids',             0.18, 'Aphid Infestation'),
    ('thrips',             0.20, 'Thrips Infestation'),
    ('mites',              0.18, 'Spider Mite Infestation'),
    ('spider mite',        0.20, 'Spider Mite Infestation'),
    ('scale insect',       0.18, 'Scale Insect Infestation'),
    ('mealy bug',          0.18, 'Mealybug Infestation'),
    ('mealybug',           0.18, 'Mealybug Infestation'),
    ('weevil',             0.22, 'Weevil Infestation'),
    ('locust',             0.35, 'Locust Infestation'),
    # ── Specific disease names ────────────────────────────────────────────
    ('mosaic disease',         0.40, 'Mosaic Virus Disease'),
    ('cassava mosaic',         0.45, 'Cassava Mosaic Disease (CMD)'),
    ('brown streak',           0.40, 'Cassava Brown Streak Disease (CBSD)'),
    ('swollen shoot',          0.40, 'Cocoa Swollen Shoot Virus (CSSV)'),
    ('vascular streak',        0.35, 'Vascular Streak Dieback (Cocoa)'),
    ('cocoa pod borer',        0.38, 'Cocoa Pod Borer (CPB)'),
    ('maize streak',           0.38, 'Maize Streak Virus (MSV)'),
    ('grey leaf spot',         0.32, 'Grey Leaf Spot (Maize)'),
    ('gray leaf spot',         0.32, 'Gray Leaf Spot (Maize)'),
    ('northern leaf blight',   0.32, 'Northern Leaf Blight (Maize)'),
    ('rice blast',             0.38, 'Rice Blast Disease'),
    ('blast',                  0.30, 'Blast Disease'),
    ('rice yellow mottle',     0.38, 'Rice Yellow Mottle Virus (RYMV)'),
    ('bacterial wilt',         0.40, 'Bacterial Wilt Disease'),
    ('fusarium',               0.34, 'Fusarium Wilt'),
    ('groundnut rosette',      0.42, 'Groundnut Rosette Virus'),
    ('rosette',                0.36, 'Rosette Virus Disease'),
    ('late blight',            0.38, 'Late Blight Disease'),
    ('early blight',           0.32, 'Early Blight Disease'),
    ('bacterial spot',         0.32, 'Bacterial Spot Disease'),
    ('nematode',               0.22, 'Nematode Infestation'),
    ('root knot',              0.24, 'Root-Knot Nematode'),
    ('anthracnose',            0.30, 'Anthracnose Disease'),
    ('downy mildew',           0.32, 'Downy Mildew Disease'),
    ('sheath blight',          0.32, 'Sheath Blight (Rice)'),
    ('common rust',            0.30, 'Common Rust (Maize/Sorghum)'),
    ('leaf rust',              0.28, 'Leaf Rust Disease'),
    ('smut',                   0.28, 'Smut Disease'),
    ('head smut',              0.30, 'Head Smut (Sorghum/Maize)'),
]


# ── Crop-specific known diseases with treatment notes ─────────────────────────

_CROP_DISEASE_INFO: Dict[str, List[Dict]] = {
    'Maize': [
        {'name': 'Fall Armyworm',          'type': 'Pest',    'risk': 'high',
         'treatment': 'Apply Neem-based biopesticide or MoFA-recommended insecticide (e.g., Coragen, Ampligo). Spray in the evening. Target the leaf whorl.',
         'prevention': 'Intercrop with legumes. Early planting to avoid peak armyworm season. Use pheromone traps for monitoring.'},
        {'name': 'Maize Streak Virus',     'type': 'Viral',   'risk': 'high',
         'treatment': 'No chemical cure. Remove and destroy infected plants. Control leafhopper vectors.',
         'prevention': 'Use MSV-tolerant varieties (e.g., Obatanpa, DK8031). Control leafhopper insects.'},
        {'name': 'Grey Leaf Spot',         'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Mancozeb or Propiconazole fungicide. Start spraying at first sign of infection.',
         'prevention': 'Rotate crops. Use resistant hybrids. Remove crop debris after harvest.'},
        {'name': 'Northern Leaf Blight',   'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Azoxystrobin or Mancozeb. Spray when lesions first appear.',
         'prevention': 'Crop rotation. Resistant varieties. Proper field drainage.'},
        {'name': 'Common Rust',            'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Propiconazole or Tebuconazole fungicide.',
         'prevention': 'Use resistant hybrids. Avoid late planting.'},
        {'name': 'Stem Borer',             'type': 'Pest',    'risk': 'high',
         'treatment': 'Apply Carbofuran granules in the whorl. Biological control using Trichogramma parasitoids.',
         'prevention': 'Destroy crop residues. Intercrop with Push-Pull plants (Desmodium).'},
        {'name': 'Ear Rot',                'type': 'Fungal',  'risk': 'high',
         'treatment': 'Harvest at the right moisture content. Dry cobs thoroughly before storage.',
         'prevention': 'Avoid delayed harvest. Store in well-ventilated cribs. Use aflatoxin-resistant varieties.'},
    ],
    'Rice': [
        {'name': 'Rice Blast',             'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Tricyclazole or Isoprothiolane fungicide at first symptoms. Avoid excess nitrogen.',
         'prevention': 'Use blast-resistant varieties (e.g., NERICA). Balanced fertiliser application.'},
        {'name': 'Rice Yellow Mottle Virus','type': 'Viral',  'risk': 'high',
         'treatment': 'No direct cure. Remove infected plants. Control insect vectors.',
         'prevention': 'Use resistant varieties. Control beetles and thrips. Avoid infected seed.'},
        {'name': 'Sheath Blight',          'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Validamycin or Hexaconazole fungicide.',
         'prevention': 'Reduce plant density. Avoid excess nitrogen. Crop rotation.'},
        {'name': 'Brown Planthopper',      'type': 'Pest',    'risk': 'high',
         'treatment': 'Apply Imidacloprid or Buprofezin insecticide.',
         'prevention': 'Monitor regularly. Avoid excess nitrogen. Maintain natural enemies.'},
        {'name': 'Bacterial Leaf Blight',  'type': 'Bacterial','risk': 'high',
         'treatment': 'Drain fields when possible. Apply copper-based bactericide.',
         'prevention': 'Use resistant varieties. Avoid excess nitrogen. Flood management.'},
    ],
    'Cassava': [
        {'name': 'Cassava Mosaic Disease', 'type': 'Viral',   'risk': 'high',
         'treatment': 'Remove and destroy infected plants. Plant clean cuttings from disease-free mother plants.',
         'prevention': 'Use CMD-resistant varieties (e.g., TME 419, Agric). Control whitefly vectors. Use clean planting material.'},
        {'name': 'Cassava Brown Streak',   'type': 'Viral',   'risk': 'high',
         'treatment': 'No cure. Rogue out infected plants. Use clean cuttings.',
         'prevention': 'Use CBSD-tolerant varieties. Control whitefly. Regular scouting.'},
        {'name': 'Whitefly Infestation',   'type': 'Pest',    'risk': 'high',
         'treatment': 'Apply Neem oil or Imidacloprid. Natural predators (parasitoid wasps) for biological control.',
         'prevention': 'Intercrop with cowpea. Monitor regularly. Remove volunteer plants.'},
        {'name': 'Cassava Anthracnose',    'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply copper-based fungicide. Remove infected stems.',
         'prevention': 'Use disease-free planting material. Avoid dense planting.'},
        {'name': 'Root Rot',               'type': 'Fungal',  'risk': 'high',
         'treatment': 'Improve soil drainage. Apply Metalaxyl to soil.',
         'prevention': 'Avoid waterlogged soils. Well-drained fields. Crop rotation.'},
    ],
    'Cocoa': [
        {'name': 'Black Pod Disease',      'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Copper-based fungicide (Ridomil Gold, Bordeaux mixture) monthly. Remove and destroy infected pods.',
         'prevention': 'Regular pod removal. Maintain proper canopy shade. Improve drainage.'},
        {'name': 'Cocoa Swollen Shoot Virus','type': 'Viral', 'risk': 'very high',
         'treatment': 'No cure. Uproot and burn infected trees. Replant with tolerant varieties.',
         'prevention': 'Use CSSV-tolerant hybrid cocoa. Control mealybug vectors. Buffer zones around infected farms.'},
        {'name': 'Cocoa Pod Borer',        'type': 'Pest',    'risk': 'high',
         'treatment': 'Frequent pod harvesting. Apply Chlorpyrifos or Lambda-cyhalothrin.',
         'prevention': 'Harvest pods as soon as ripe. Bury or compost pod husks.'},
        {'name': 'Vascular Streak Dieback','type': 'Fungal',  'risk': 'high',
         'treatment': 'Prune diseased branches well below infection point. Apply copper-based fungicide on cuts.',
         'prevention': 'Use disease-resistant planting material. Proper canopy management.'},
        {'name': 'Capsid Bug (Mirid)',      'type': 'Pest',   'risk': 'high',
         'treatment': 'Apply Chlorpyrifos or Cypermethrin insecticide in the evening.',
         'prevention': 'Regular monitoring. Maintain proper shade. Early treatment.'},
    ],
    'Tomato': [
        {'name': 'Late Blight',            'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Mancozeb, Metalaxyl, or Cymoxanil+Mancozeb. Spray every 7 days during rainy season.',
         'prevention': 'Avoid overhead irrigation. Improve airflow. Use resistant varieties. Crop rotation.'},
        {'name': 'Early Blight',           'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Chlorothalonil or copper fungicide. Remove lower infected leaves.',
         'prevention': 'Mulch around plants. Avoid wetting leaves. Stake plants for airflow.'},
        {'name': 'Bacterial Wilt',         'type': 'Bacterial','risk': 'high',
         'treatment': 'No effective chemical cure. Remove and destroy infected plants immediately.',
         'prevention': 'Crop rotation (3–4 years). Use resistant varieties. Improve soil drainage.'},
        {'name': 'Tomato Yellow Leaf Curl Virus','type': 'Viral','risk': 'high',
         'treatment': 'Control whitefly vectors. Remove infected plants.',
         'prevention': 'Use TYLCV-resistant varieties. Insect-proof nursery. Neem oil for whitefly.'},
        {'name': 'Fusarium Wilt',          'type': 'Fungal',  'risk': 'high',
         'treatment': 'No chemical cure once established. Remove infected plants.',
         'prevention': 'Use resistant varieties. Soil solarisation. Proper rotation.'},
    ],
    'Pepper': [
        {'name': 'Bacterial Spot',         'type': 'Bacterial','risk': 'moderate',
         'treatment': 'Apply copper-based bactericide. Remove and destroy infected plant debris.',
         'prevention': 'Use certified disease-free seeds. Avoid overhead watering. Crop rotation.'},
        {'name': 'Anthracnose',            'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Mancozeb or Azoxystrobin. Harvest before full maturity to avoid infection.',
         'prevention': 'Improve drainage. Avoid mechanical damage to fruits. Use clean seed.'},
        {'name': 'Pepper Mosaic Virus',    'type': 'Viral',   'risk': 'high',
         'treatment': 'Remove infected plants. Control aphid vectors with Imidacloprid or Neem oil.',
         'prevention': 'Use virus-free seeds. Control aphids. Physical barriers.'},
        {'name': 'Phytophthora Root Rot',  'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Metalaxyl soil drench. Improve drainage.',
         'prevention': 'Well-drained soils. Raised beds. Avoid overwatering.'},
    ],
    'Groundnut': [
        {'name': 'Groundnut Rosette Virus','type': 'Viral',   'risk': 'very high',
         'treatment': 'No cure. Remove and destroy infected plants early. Control aphid vectors.',
         'prevention': 'Use tolerant varieties (e.g., Azivivi). Early planting. Border rows of maize or sorghum.'},
        {'name': 'Early Leaf Spot',        'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Chlorothalonil or Mancozeb every 14 days.',
         'prevention': 'Crop rotation (2–3 years). Remove plant debris. Resistant varieties.'},
        {'name': 'Late Leaf Spot',         'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Propiconazole or Tebuconazole. Start spraying at first sign.',
         'prevention': 'Crop rotation. Remove plant debris. Balanced fertilisation.'},
        {'name': 'Aflatoxin (Aspergillus)','type': 'Fungal',  'risk': 'very high',
         'treatment': 'Harvest on time. Dry pods to below 10% moisture immediately. Use aflatoxin-control products in storage.',
         'prevention': 'Avoid drought stress at pod filling. Timely harvest. Proper drying and storage.'},
    ],
    'Soybean': [
        {'name': 'Soybean Rust',           'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Azoxystrobin, Trifloxystrobin, or Tebuconazole.',
         'prevention': 'Use resistant varieties. Crop rotation. Early planting.'},
        {'name': 'Pod and Stem Blight',    'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Carbendazim or Thiophanate-methyl at pod fill.',
         'prevention': 'Use clean seed. Avoid delayed harvest.'},
        {'name': 'Bacterial Pustule',      'type': 'Bacterial','risk': 'low',
         'treatment': 'Apply copper-based bactericide if severe.',
         'prevention': 'Use certified seed. Crop rotation.'},
    ],
    'Cowpea': [
        {'name': 'Cowpea Mosaic Virus',    'type': 'Viral',   'risk': 'high',
         'treatment': 'Remove infected plants. Control aphid and beetle vectors.',
         'prevention': 'Use resistant varieties. Control insect vectors. Crop rotation.'},
        {'name': 'Brown Blotch',           'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Mancozeb or copper fungicide.',
         'prevention': 'Remove infected debris. Avoid overhead watering. Crop rotation.'},
        {'name': 'Pod Borer',              'type': 'Pest',    'risk': 'high',
         'treatment': 'Apply Cypermethrin or Dimethoate at flowering.',
         'prevention': 'Early planting. Monitor flower stage closely.'},
        {'name': 'Striga (Witchweed)',     'type': 'Parasitic','risk': 'high',
         'treatment': 'Hand-weed before Striga flowers. Use Imazapyr-treated seed.',
         'prevention': 'Crop rotation with non-host crops. Use Striga-resistant cowpea varieties.'},
    ],
    'Yam': [
        {'name': 'Yam Mosaic Virus',       'type': 'Viral',   'risk': 'high',
         'treatment': 'Use virus-free seed yam. Remove infected plants.',
         'prevention': 'Clean planting material from certified sources. Control aphid vectors.'},
        {'name': 'Anthracnose',            'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply copper-based fungicide to tubers before planting. Avoid injury during harvest.',
         'prevention': 'Treat seed yam with fungicide. Proper storage. Crop rotation.'},
        {'name': 'Dry Rot',                'type': 'Fungal',  'risk': 'high',
         'treatment': 'Use Mancozeb or Metalaxyl treatment on seed yam.',
         'prevention': 'Certified seed yam. Proper storage (cool, ventilated). Avoid mechanical damage.'},
        {'name': 'Root-Knot Nematode',     'type': 'Pest',    'risk': 'moderate',
         'treatment': 'Apply Carbofuran nematicide. Solarise soil.',
         'prevention': 'Crop rotation. Use clean planting material.'},
    ],
    'Plantain': [
        {'name': 'Black Sigatoka',         'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Propiconazole or Azoxystrobin. Remove and destroy infected leaves.',
         'prevention': 'Remove diseased leaves. Ensure adequate spacing. Drainage.'},
        {'name': 'Banana Bunchy Top Virus','type': 'Viral',   'risk': 'very high',
         'treatment': 'Uproot and destroy infected plants immediately.',
         'prevention': 'Use virus-free planting material. Control aphid vectors.'},
        {'name': 'Xanthomonas Wilt',       'type': 'Bacterial','risk': 'very high',
         'treatment': 'No chemical cure. Rogue infected plants. Sterilise cutting tools.',
         'prevention': 'Use single-node cutting. Sterilise tools between plants.'},
        {'name': 'Weevil (Cosmopolites)',   'type': 'Pest',   'risk': 'high',
         'treatment': 'Use Chlorpyrifos or remove infested material. Biological control with Beauveria bassiana.',
         'prevention': 'Plant traps. Remove corm debris. Use clean planting material.'},
    ],
    'Millet': [
        {'name': 'Downy Mildew',           'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Metalaxyl or Cymoxanil. Remove infected plants.',
         'prevention': 'Use resistant varieties. Treat seed with Metalaxyl. Crop rotation.'},
        {'name': 'Head Smut',              'type': 'Fungal',  'risk': 'high',
         'treatment': 'Remove smut balls before they open. Treat seed with systemic fungicide.',
         'prevention': 'Use smut-free seed. Treat seed with Carboxin+Thiram.'},
        {'name': 'Striga',                 'type': 'Parasitic','risk': 'very high',
         'treatment': 'Hand-pull before Striga seeds set. Apply Imazapyr or 2,4-D.',
         'prevention': 'Crop rotation. Striga-resistant varieties. Intercrop with legumes.'},
    ],
    'Sorghum': [
        {'name': 'Head Smut',              'type': 'Fungal',  'risk': 'high',
         'treatment': 'Remove smut galls. Treat seed with Carboxin fungicide.',
         'prevention': 'Use smut-free seed. Crop rotation.'},
        {'name': 'Anthracnose',            'type': 'Fungal',  'risk': 'high',
         'treatment': 'Apply Propiconazole. Remove infected stalk residues.',
         'prevention': 'Resistant varieties. Crop rotation.'},
        {'name': 'Striga',                 'type': 'Parasitic','risk': 'very high',
         'treatment': 'Early hand-weeding. Imazapyr-treated seed.',
         'prevention': 'Crop rotation with legumes. Striga-resistant sorghum varieties.'},
        {'name': 'Common Rust',            'type': 'Fungal',  'risk': 'moderate',
         'treatment': 'Apply Propiconazole or copper fungicide.',
         'prevention': 'Use resistant varieties. Early planting.'},
    ],
}

# GDD (Growing Degree Days) requirements per crop
_GDD_TO_HARVEST: Dict[str, int] = {
    'Maize': 1200, 'Rice': 1400, 'Tomato': 900, 'Pepper': 1100,
    'Cassava': 3000, 'Yam': 2500, 'Groundnut': 1300, 'Soybean': 1300,
    'Cowpea': 1000, 'Millet': 1000, 'Sorghum': 1200, 'Cocoa': 0,
    'Plantain': 1800, 'Cocoyam': 2000, 'Sweet Potato': 1400, 'Okra': 800,
    'Watermelon': 1100, 'Sugarcane': 3500, 'Oil Palm': 0, 'Banana': 2000,
}


class AdvisoryEngine:
    """
    Heuristic advisory engine for Ghana crop disease and stress assessment.

    Inputs:  crop name, symptoms text, weather data, quality score,
             observed disease name (optional), diary summary (optional)

    Outputs: disease_risk [0,1], weather_risk [0,1], yield_factor [0.6,1.05],
             identified disease, treatment recommendations, advisory tips
    """

    def diagnose(self,
                 crop: str,
                 region: str,
                 symptoms: Optional[str] = None,
                 observed_disease: Optional[str] = None,
                 weather: Optional[dict] = None,
                 quality_score: Optional[float] = None,
                 diary_summary: Optional[dict] = None) -> dict:
        """
        Assess crop health risk from available signals.

        Returns a dict with:
            disease_risk     [0,1]
            weather_risk     [0,1]
            disease_name     str — best-matched disease
            yield_factor     float — [0.60, 1.05] multiplier for yield adjustment
            evidence         list — signals that contributed to the risk score
            treatment        str — recommended treatment
            prevention       str — prevention advice
            common_diseases_for_crop  list — known diseases for this crop
        """
        norm_crop   = _normalise_crop(crop)
        symptom_txt = _normalise_text(symptoms)
        disease_txt = _normalise_text(observed_disease)

        disease_risk  = 0.0
        disease_name  = 'None detected'
        treatment     = ''
        prevention    = ''
        evidence      = []

        # ── 1. Directly reported disease name ─────────────────────────────────
        if observed_disease:
            disease_name  = observed_disease.strip().title()
            disease_risk += 0.55
            evidence.append(f'farmer_reported: {disease_name}')
            # Look for treatment from crop-disease info
            treatment, prevention = self._lookup_treatment(norm_crop, disease_name)

        # ── 2. Symptom pattern matching ────────────────────────────────────────
        matched_hints: List[str] = []
        for phrase, score, hint in _SYMPTOM_MAP:
            if phrase in symptom_txt:
                disease_risk += score
                evidence.append(f'symptom: {phrase}')
                matched_hints.append(hint)
                if disease_name == 'None detected' and hint:
                    disease_name = hint

        # Refine disease name using crop context when symptom hints are available
        if matched_hints and disease_name in ('None detected', matched_hints[0]):
            disease_name = self._refine_diagnosis(norm_crop, symptom_txt, disease_txt, matched_hints)
            treatment, prevention = self._lookup_treatment(norm_crop, disease_name)

        # ── 3. Check reported disease name text for known pattern names ────────
        if disease_txt and not treatment:
            for phrase, score, hint in _SYMPTOM_MAP:
                if phrase in disease_txt:
                    disease_risk = max(disease_risk, score + 0.30)
                    if disease_name == 'None detected':
                        disease_name = hint or observed_disease.title()
                    treatment, prevention = self._lookup_treatment(norm_crop, disease_name)
                    evidence.append(f'disease_text_match: {phrase}')
                    break

        # ── 4. Weather risk ────────────────────────────────────────────────────
        weather_risk = self._weather_risk(weather)
        if weather_risk > 0.05:
            evidence.append(f'weather_risk: {weather_risk:.2f}')
            # High humidity + symptoms amplify fungal risk
            if weather_risk >= 0.25 and any('fungal' in h.lower() or 'blight' in h.lower() or 'rust' in h.lower()
                                             for h in matched_hints):
                disease_risk += 0.10

        # ── 5. Quality score signal ────────────────────────────────────────────
        quality_note = ''
        if quality_score is not None:
            qs = float(quality_score)
            if qs <= 4.0:
                disease_risk += 0.12
                quality_note  = 'Low quality score suggests late-season stress or disease damage.'
                evidence.append('low_quality_score')
            elif qs >= 8.5:
                quality_note  = 'High quality score indicates healthy crop and good management.'

        # ── 6. Diary-based signal ──────────────────────────────────────────────
        if diary_summary:
            pest_evt    = int(diary_summary.get('pest_events', 0) or 0)
            disease_evt = int(diary_summary.get('disease_events', 0) or 0)
            if pest_evt:
                disease_risk += pest_evt * 0.04
                evidence.append(f'diary_pest_events: {pest_evt}')
            if disease_evt:
                disease_risk += disease_evt * 0.05
                evidence.append(f'diary_disease_events: {disease_evt}')

        # ── 7. Combine and cap ─────────────────────────────────────────────────
        disease_risk = round(min(1.0, disease_risk + weather_risk), 3)

        # Yield adjustment: no risk → 1.05 (slight boost for low-risk good crop)
        #                   max risk → 0.60 (40% yield loss at maximum disease)
        yield_factor = round(max(0.60, 1.05 - disease_risk * 0.45), 3)

        # Common diseases for this crop (for UI display)
        crop_diseases = self._disease_names(norm_crop)

        return {
            'crop':                      crop,
            'region':                    region,
            'disease_name':              disease_name,
            'disease_risk':              disease_risk,
            'weather_risk':              round(weather_risk, 3),
            'quality_score':             quality_score,
            'quality_note':              quality_note,
            'yield_factor':              yield_factor,
            'treatment':                 treatment,
            'prevention':                prevention,
            'evidence':                  evidence,
            'common_diseases_for_crop':  crop_diseases,
        }

    def generate_advisory(self,
                          crop: str,
                          region: str,
                          disease_risk: float,
                          weather_risk: float = 0.0,
                          quality_score: Optional[float] = None,
                          diary_summary: Optional[dict] = None,
                          treatment: str = '',
                          prevention: str = '') -> dict:
        """
        Generate actionable advisory tips from risk scores and context.
        """
        tips: List[str] = []
        summary_parts: List[str] = [f'Crop: {crop}. Region: {region}.']

        # ── Disease risk tier ──────────────────────────────────────────────────
        if disease_risk >= 0.70:
            summary_parts.append('HIGH disease/pest risk detected — immediate action required.')
            tips.append('Inspect every plant row daily and isolate visibly affected plants.')
            tips.append('Apply crop-specific fungicide/insecticide immediately — delay worsens spread.')
            tips.append('Do NOT spray during rain or strong wind — it reduces chemical effectiveness.')
            if treatment:
                tips.append(f'Recommended treatment: {treatment}')
        elif disease_risk >= 0.40:
            summary_parts.append('Moderate disease risk — preventive action recommended.')
            tips.append('Scout fields at least twice per week for early symptom detection.')
            tips.append('Apply preventive fungicide/insecticide spray as per MoFA guidance.')
            tips.append('Ensure good airflow — thin plants if canopy is too dense.')
            if treatment:
                tips.append(f'Suggested treatment: {treatment}')
        else:
            summary_parts.append('Low disease risk — routine monitoring is sufficient.')
            tips.append('Continue routine field scouting once per week.')
            tips.append('Maintain field hygiene — remove crop debris and volunteer plants.')

        # ── Prevention advice ──────────────────────────────────────────────────
        if prevention:
            tips.append(f'Prevention: {prevention}')

        # ── Weather-specific tips ──────────────────────────────────────────────
        if weather_risk >= 0.50:
            summary_parts.append('Weather conditions are favouring disease spread.')
            tips.append('Delay foliar spraying until after rain stops and wind is calm.')
            tips.append('Check drainage — waterlogged soils rapidly cause root rot.')
            tips.append('After prolonged rain, scout for fungal symptoms (blight, mildew) within 3 days.')
        elif weather_risk >= 0.20:
            tips.append('Recent humid or rainy weather increases fungal disease pressure.')
            tips.append('Avoid overhead irrigation when humidity is already high.')

        # ── Quality advice ──────────────────────────────────────────────────────
        if quality_score is not None:
            qs = float(quality_score)
            if qs >= 8.0:
                tips.append('Excellent quality — target premium buyers and agro-processors.')
                tips.append('Maintain post-harvest handling standards to preserve your quality grade.')
            elif qs <= 4.0:
                tips.append('Poor quality score — review post-harvest storage and handling immediately.')
                tips.append('Check for aflatoxin risk if storing in humid or warm conditions.')
            else:
                tips.append('Quality is acceptable — maintain detailed field records for buyer confidence.')

        # ── Diary-based contextual tips ────────────────────────────────────────
        if diary_summary:
            rain_mm = float(diary_summary.get('total_rainfall_mm') or 0)
            fert_n  = int(diary_summary.get('fertilizer_applications') or 0)
            irr     = int(diary_summary.get('irrigation_days') or 0)
            if rain_mm < 200:
                tips.append(f'Season rainfall is low ({rain_mm:.0f} mm). Supplement with '
                             'irrigation if available, especially during flowering.')
            if fert_n == 0:
                tips.append('No fertiliser application recorded. Consider top-dressing with '
                             'NPK if the crop is still in the vegetative stage.')
            if irr > 10:
                tips.append('Frequent irrigation noted — verify soil drainage to prevent waterlogging.')

        return {
            'summary':      ' '.join(summary_parts),
            'tips':         tips,
            'risk_level':   ('high'     if disease_risk >= 0.70 else
                             'moderate' if disease_risk >= 0.40 else 'low'),
            'disease_risk':  round(disease_risk, 3),
            'weather_risk':  round(weather_risk, 3),
        }

    def estimate_days_to_harvest(self,
                                 crop: str,
                                 accumulated_gdd: float,
                                 avg_gdd_per_day: float) -> Optional[int]:
        """Estimate remaining days to harvest using GDD thresholds."""
        norm = _normalise_crop(crop)
        needed = _GDD_TO_HARVEST.get(norm)
        if needed is None or needed == 0:
            return None
        remaining = max(0.0, needed - float(accumulated_gdd))
        if avg_gdd_per_day <= 0:
            return None
        return int(round(remaining / avg_gdd_per_day))

    # ── Internal helpers ───────────────────────────────────────────────────────

    def _disease_names(self, crop: str) -> List[str]:
        diseases = _CROP_DISEASE_INFO.get(crop, [])
        if diseases:
            return [d['name'] for d in diseases]
        return ['Consult your local MoFA extension officer for crop-specific disease advice.']

    def _lookup_treatment(self, crop: str, disease_name: str) -> Tuple[str, str]:
        """Find treatment and prevention advice for a specific crop disease."""
        disease_name_lower = disease_name.lower()
        diseases = _CROP_DISEASE_INFO.get(crop, [])
        for d in diseases:
            if d['name'].lower() in disease_name_lower or disease_name_lower in d['name'].lower():
                return d.get('treatment', ''), d.get('prevention', '')
        # Try partial match across all crops
        for crop_diseases in _CROP_DISEASE_INFO.values():
            for d in crop_diseases:
                dname = d['name'].lower()
                if dname in disease_name_lower or any(word in disease_name_lower
                                                       for word in dname.split() if len(word) > 4):
                    return d.get('treatment', ''), d.get('prevention', '')
        return '', ''

    def _refine_diagnosis(self, crop: str, symptom_txt: str,
                          disease_txt: str, hints: List[str]) -> str:
        """
        Use crop context + matched symptom hints to identify the most likely
        specific disease name rather than a generic category.
        """
        if not hints:
            return 'Unidentified Stress'

        combined = symptom_txt + ' ' + disease_txt

        # Crop-specific refinement rules
        if crop == 'Maize':
            if any(w in combined for w in ('armyworm', 'chewed', 'caterpillar', 'holes in leaves')):
                return 'Fall Armyworm (Spodoptera frugiperda)'
            if any(w in combined for w in ('streak', 'stripe', 'yellowing stripe', 'maize streak')):
                return 'Maize Streak Virus (MSV)'
            if any(w in combined for w in ('borer', 'stem borer', 'dead heart')):
                return 'Stem Borer'
            if any(w in combined for w in ('ear rot', 'grain mold', 'aflatoxin')):
                return 'Ear Rot / Aflatoxin Risk'
            if any(w in combined for w in ('grey leaf', 'gray leaf', 'leaf spot')):
                return 'Grey Leaf Spot'
            if 'rust' in combined:
                return 'Common Rust'
            if any(w in combined for w in ('blight', 'northern leaf')):
                return 'Northern Leaf Blight'

        elif crop == 'Cassava':
            if any(w in combined for w in ('mosaic', 'mottl', 'yellowing', 'yellow mosaic')):
                return 'Cassava Mosaic Disease (CMD)'
            if any(w in combined for w in ('brown streak', 'necrosis', 'tuber brown')):
                return 'Cassava Brown Streak Disease (CBSD)'
            if any(w in combined for w in ('whitefly', 'white fly')):
                return 'Whitefly Infestation (CMD vector)'
            if any(w in combined for w in ('root rot', 'stem rot', 'wilting')):
                return 'Root Rot'
            if 'anthracnose' in combined:
                return 'Cassava Anthracnose'

        elif crop == 'Cocoa':
            if any(w in combined for w in ('black pod', 'pod rot', 'pod discolor')):
                return 'Black Pod Disease (Phytophthora)'
            if any(w in combined for w in ('swollen shoot', 'swollen stem', 'cssv')):
                return 'Cocoa Swollen Shoot Virus (CSSV)'
            if any(w in combined for w in ('pod borer', 'borer', 'holes in pod')):
                return 'Cocoa Pod Borer (CPB)'
            if any(w in combined for w in ('vascular', 'dieback', 'branch die')):
                return 'Vascular Streak Dieback'
            if any(w in combined for w in ('capsid', 'mirid', 'brown mark')):
                return 'Capsid Bug (Sahlbergella singularis)'

        elif crop == 'Rice':
            if any(w in combined for w in ('blast', 'diamond spots', 'collar rot')):
                return 'Rice Blast (Pyricularia oryzae)'
            if any(w in combined for w in ('yellow mottle', 'rymv')):
                return 'Rice Yellow Mottle Virus (RYMV)'
            if any(w in combined for w in ('sheath blight', 'sheath rot')):
                return 'Sheath Blight'
            if any(w in combined for w in ('bacterial leaf blight', 'blight', 'water-soaked')):
                return 'Bacterial Leaf Blight'
            if any(w in combined for w in ('brown planthopper', 'planthopper')):
                return 'Brown Planthopper'

        elif crop == 'Tomato':
            if any(w in combined for w in ('late blight', 'dark lesion', 'water soaked lesion')):
                return 'Late Blight (Phytophthora infestans)'
            if any(w in combined for w in ('early blight', 'target spot', 'concentric')):
                return 'Early Blight (Alternaria solani)'
            if any(w in combined for w in ('wilt', 'wilting', 'bacterial wilt')):
                return 'Bacterial Wilt (Ralstonia solanacearum)'
            if any(w in combined for w in ('curl', 'yellowing', 'leaf curl', 'tylcv')):
                return 'Tomato Yellow Leaf Curl Virus (TYLCV)'
            if 'mosaic' in combined:
                return 'Tomato Mosaic Virus'

        elif crop == 'Groundnut':
            if any(w in combined for w in ('rosette', 'mosaic', 'mottl')):
                return 'Groundnut Rosette Virus'
            if any(w in combined for w in ('leaf spot', 'early spot', 'cercospora')):
                return 'Early Leaf Spot (Cercospora arachidicola)'
            if any(w in combined for w in ('aflatoxin', 'mold', 'moldy')):
                return 'Aflatoxin (Aspergillus flavus)'

        elif crop == 'Sorghum' or crop == 'Millet':
            if any(w in combined for w in ('striga', 'witchweed', 'purple weed')):
                return 'Striga (Witchweed) Infestation'
            if any(w in combined for w in ('smut', 'head smut')):
                return 'Head Smut Disease'
            if any(w in combined for w in ('downy mildew', 'green ear')):
                return 'Downy Mildew'

        # Fall back to the best matched hint
        return hints[0]

    def _weather_risk(self, weather) -> float:
        if not weather:
            return 0.0
        if isinstance(weather, str):
            txt = weather.lower()
            risk = 0.0
            if any(w in txt for w in ('rain', 'storm', 'flood')):
                risk += 0.28
            if any(w in txt for w in ('humid', 'wet', 'moisture')):
                risk += 0.15
            return min(1.0, risk)

        if isinstance(weather, dict):
            humidity = float(weather.get('humidity', 0) or 0)
            rainfall = float(
                weather.get('rainfallNext24hMm')
                or weather.get('rainfall_mm')
                or weather.get('rainfall', 0)
                or 0
            )
            temp = float(
                weather.get('temperatureC')
                or weather.get('temp_c')
                or weather.get('temp', 25)
                or 25
            )
            risk = 0.0
            if humidity >= 85 or rainfall >= 20:
                risk += 0.35
            elif humidity >= 75 or rainfall >= 10:
                risk += 0.22
            elif humidity >= 65 or rainfall >= 5:
                risk += 0.10

            if temp >= 36 or temp <= 12:
                risk += 0.12
            elif temp >= 33 or temp <= 15:
                risk += 0.06

            desc = str(weather.get('description', '') or '').lower()
            if any(w in desc for w in ('storm', 'thunder', 'heavy rain', 'flood')):
                risk += 0.12

            return min(1.0, risk)
        return 0.0
