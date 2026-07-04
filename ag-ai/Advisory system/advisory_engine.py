"""
AgriGuard Advisory Engine
=========================
Text-based crop disease diagnosis for Ghana smallholder farms.

Diagnosis uses a voting system:
  - Each symptom keyword that matches contributes a vote to a specific disease
  - The disease with the highest total vote score wins
  - Confidence = winning score / max possible score for that disease
  - Generic fallback only when no crop-specific disease is matched
"""

from __future__ import annotations
from typing import Optional, Dict, List, Tuple


# ── Crop name normalisation ───────────────────────────────────────────────────

_CROP_ALIASES: Dict[str, str] = {
    'maize': 'Maize', 'corn': 'Maize',
    'rice': 'Rice', 'paddy': 'Rice',
    'cassava': 'Cassava', 'tapioca': 'Cassava',
    'yam': 'Yam',
    'tomato': 'Tomato', 'tomatoes': 'Tomato',
    'pepper': 'Pepper', 'chili': 'Pepper', 'chilli': 'Pepper',
    'cocoa': 'Cocoa', 'cacao': 'Cocoa',
    'groundnut': 'Groundnut', 'peanut': 'Groundnut', 'groundnuts': 'Groundnut',
    'soybean': 'Soybean', 'soya': 'Soybean', 'soybeans': 'Soybean',
    'cowpea': 'Cowpea', 'cowpeas': 'Cowpea',
    'plantain': 'Plantain',
    'millet': 'Millet', 'pearl millet': 'Millet',
    'sorghum': 'Sorghum', 'guinea corn': 'Sorghum',
    'cocoyam': 'Cocoyam', 'taro': 'Cocoyam',
    'sweet potato': 'Sweet Potato',
    'okra': 'Okra', 'okro': 'Okra',
    'banana': 'Banana',
    'oil palm': 'Oil Palm',
    'onion': 'Onion', 'onions': 'Onion',
}


def _normalise_crop(crop: str) -> str:
    if not crop:
        return 'Unknown'
    return _CROP_ALIASES.get(crop.strip().lower(), crop.strip().title())


def _normalise_text(text: Optional[str]) -> str:
    return (text or '').strip().lower()


# ── Crop-specific symptom → disease voting maps ───────────────────────────────
# Format: (keyword_list, disease_name, vote_weight)
# A disease score = sum of vote_weight for each keyword matched.
# The disease with highest total score wins.

_CROP_SYMPTOM_VOTES: Dict[str, List[Tuple[List[str], str, float]]] = {

    'Maize': [
        (['armyworm', 'fall armyworm', 'chewed leaves', 'caterpillar', 'holes in leaves', 'eaten leaves'],
         'Fall Armyworm (Spodoptera frugiperda)', 1.0),
        (['streak', 'maize streak', 'yellow streak', 'stripe', 'yellowing stripes', 'leafhopper'],
         'Maize Streak Virus (MSV)', 1.0),
        (['stem borer', 'borer', 'dead heart', 'tunnel', 'frass in stem'],
         'Stem Borer', 0.9),
        (['grey leaf spot', 'gray leaf spot', 'rectangular lesion', 'small grey spots'],
         'Grey Leaf Spot', 0.9),
        (['northern leaf blight', 'cigar lesion', 'long grey lesion', 'nlb'],
         'Northern Leaf Blight', 0.9),
        (['rust', 'common rust', 'orange pustule', 'rusty powder', 'orange spots'],
         'Common Rust', 0.8),
        (['ear rot', 'moldy grain', 'grain rot', 'aflatoxin', 'discolored grain'],
         'Ear Rot / Aflatoxin Risk', 0.9),
        (['stalk rot', 'stalk collapse', 'lodging', 'stem soft', 'hollow stem'],
         'Stalk Rot', 0.8),
        (['downy mildew', 'white downy', 'systemic chlorosis'],
         'Maize Downy Mildew', 0.8),
        (['mosaic', 'mottling', 'mottled'],
         'Maize Dwarf Mosaic Virus', 0.7),
    ],

    'Cassava': [
        (['cassava mosaic', 'mosaic', 'mottled leaves', 'yellowing mosaic', 'distorted leaves', 'whitefly'],
         'Cassava Mosaic Disease (CMD)', 1.0),
        (['brown streak', 'cassava brown streak', 'cbsd', 'tuber necrosis', 'brown tuber'],
         'Cassava Brown Streak Disease (CBSD)', 1.0),
        (['root rot', 'stem rot', 'collar rot', 'wilting', 'stem blackening'],
         'Root Rot (Phytophthora)', 0.9),
        (['anthracnose', 'stem lesion', 'stem canker', 'dieback'],
         'Cassava Anthracnose', 0.8),
        (['bacterial blight', 'leaf blight', 'water-soaked spots', 'gum exudate'],
         'Cassava Bacterial Blight', 0.9),
        (['mealybug', 'mealy bug', 'white cottony', 'stunted growth'],
         'Cassava Mealybug Infestation', 0.8),
        (['green mite', 'spider mite', 'mite', 'leaf yellowing mite'],
         'Cassava Green Mite', 0.7),
    ],

    'Rice': [
        (['blast', 'rice blast', 'diamond spot', 'diamond lesion', 'grey center lesion', 'collar rot'],
         'Rice Blast (Pyricularia oryzae)', 1.0),
        (['yellow mottle', 'rymv', 'yellow discoloration', 'stunted yellow'],
         'Rice Yellow Mottle Virus (RYMV)', 1.0),
        (['sheath blight', 'sheath lesion', 'oval lesion on sheath'],
         'Sheath Blight (Rhizoctonia)', 0.9),
        (['bacterial leaf blight', 'water-soaked leaf margin', 'wilting seedling', 'kresek'],
         'Bacterial Leaf Blight', 0.9),
        (['brown planthopper', 'planthopper', 'hopperburn', 'basal yellowing'],
         'Brown Planthopper', 0.9),
        (['stem borer', 'borer', 'dead heart', 'white ear', 'whitehead'],
         'Rice Stem Borer', 0.8),
        (['false smut', 'green ball', 'grain smut', 'olive green spore'],
         'False Smut', 0.8),
        (['brown spot', 'helminthosporium', 'oval brown spot on leaf'],
         'Brown Spot Disease', 0.7),
    ],

    'Tomato': [
        (['late blight', 'water-soaked lesion', 'dark brown lesion', 'white mold underleaf', 'phytophthora'],
         'Late Blight (Phytophthora infestans)', 1.0),
        (['early blight', 'target spot', 'concentric ring', 'alternaria', 'lower leaf spot'],
         'Early Blight (Alternaria solani)', 0.9),
        (['bacterial wilt', 'wilting', 'sudden wilt', 'ooze stem', 'ralstonia'],
         'Bacterial Wilt (Ralstonia solanacearum)', 1.0),
        (['leaf curl', 'tylcv', 'yellow curl', 'whitefly', 'curling yellow leaves'],
         'Tomato Yellow Leaf Curl Virus (TYLCV)', 1.0),
        (['fusarium', 'fusarium wilt', 'yellowing one side', 'vascular browning'],
         'Fusarium Wilt', 0.9),
        (['mosaic', 'tomato mosaic', 'mottled', 'distorted fruit'],
         'Tomato Mosaic Virus', 0.8),
        (['blossom end rot', 'black bottom fruit', 'sunken dark bottom'],
         'Blossom End Rot (Calcium)', 0.9),
        (['septoria leaf spot', 'small white spot', 'tiny circular spot'],
         'Septoria Leaf Spot', 0.8),
        (['spider mite', 'mite', 'bronze discoloration', 'stippling'],
         'Spider Mite Infestation', 0.7),
    ],

    'Cocoa': [
        (['black pod', 'pod rot', 'pod discolor', 'phytophthora pod', 'dark pod'],
         'Black Pod Disease (Phytophthora)', 1.0),
        (['swollen shoot', 'cssv', 'red vein', 'swollen stem', 'mealybug vector'],
         'Cocoa Swollen Shoot Virus (CSSV)', 1.0),
        (['pod borer', 'cocoa pod borer', 'cpb', 'tunnel in pod', 'premature ripening'],
         'Cocoa Pod Borer (CPB)', 0.9),
        (['vascular streak', 'dieback', 'vsd', 'green vein', 'wilted flush'],
         'Vascular Streak Dieback (VSD)', 0.9),
        (['capsid', 'mirid', 'brown mark on pod', 'corky lesion', 'angular lesion'],
         'Capsid Bug (Sahlbergella singularis)', 0.8),
        (['witches broom', 'fan branch', 'broom like growth'],
         "Witches' Broom Disease", 0.8),
        (['mealybug', 'white cottony', 'ant colony', 'honeydew'],
         'Mealybug Infestation', 0.7),
    ],

    'Groundnut': [
        (['rosette', 'groundnut rosette', 'stunted mosaic', 'small leaflet', 'aphid vector'],
         'Groundnut Rosette Virus', 1.0),
        (['early leaf spot', 'cercospora', 'early spot', 'circular dark spot'],
         'Early Leaf Spot (Cercospora arachidicola)', 0.9),
        (['late leaf spot', 'late spot', 'phaeoariulariopsis', 'darker spot lower'],
         'Late Leaf Spot', 0.9),
        (['aflatoxin', 'mold', 'mould', 'discolored pod', 'moldy kernel'],
         'Aflatoxin (Aspergillus flavus)', 1.0),
        (['rust', 'groundnut rust', 'orange pustule underleaf'],
         'Groundnut Rust', 0.8),
        (['collar rot', 'stem rot', 'seedling death', 'sclerotinia'],
         'Collar Rot (Aspergillus niger)', 0.8),
        (['pod rot', 'wet soil rot', 'pythium'],
         'Pod Rot', 0.7),
    ],

    'Yam': [
        (['mosaic', 'yam mosaic', 'mottled yellow', 'distorted leaf'],
         'Yam Mosaic Virus (YMV)', 1.0),
        (['anthracnose', 'leaf spot yam', 'stem lesion', 'colletotrichum'],
         'Yam Anthracnose', 0.9),
        (['dry rot', 'tuber dry rot', 'shrunken tuber', 'internal rot'],
         'Dry Rot (Sclerotium)', 0.9),
        (['root knot', 'nematode', 'galls on root', 'knobby root'],
         'Root-Knot Nematode', 0.8),
        (['soft rot', 'wet rot', 'tuber watery', 'storage rot'],
         'Soft Rot (Erwinia)', 0.8),
        (['leaf blight', 'curvularia', 'large brown lesion'],
         'Leaf Blight', 0.7),
    ],

    'Pepper': [
        (['bacterial spot', 'water-soaked spot', 'raised spot', 'xanthomonas'],
         'Bacterial Spot', 0.9),
        (['anthracnose', 'fruit rot', 'sunken fruit lesion', 'colletotrichum'],
         'Anthracnose / Fruit Rot', 0.9),
        (['mosaic', 'pepper mosaic', 'mottled', 'distorted fruit', 'aphid vector'],
         'Pepper Mosaic Virus', 1.0),
        (['phytophthora', 'root rot', 'crown rot', 'sudden wilt', 'wilting'],
         'Phytophthora Root Rot', 0.9),
        (['thrips', 'silvering', 'scarring', 'curling upward'],
         'Thrips Infestation', 0.8),
        (['powdery mildew', 'white coating on leaf', 'white powder'],
         'Powdery Mildew', 0.8),
    ],

    'Plantain': [
        (['black sigatoka', 'sigatoka', 'dark streak on leaf', 'yellow leaf', 'banana leaf streak'],
         'Black Sigatoka (Mycosphaerella fijiensis)', 1.0),
        (['bunchy top', 'bbmv', 'strap leaves', 'dark green streak on petiole'],
         'Banana Bunchy Top Virus (BBTV)', 1.0),
        (['xanthomonas wilt', 'xanthom', 'wilting banana', 'yellow ooze from stem'],
         'Xanthomonas Wilt (BXW)', 1.0),
        (['weevil', 'cosmopolites', 'corm weevil', 'tunnel in corm'],
         'Banana Weevil (Cosmopolites sordidus)', 0.9),
        (['panama disease', 'fusarium', 'yellowing inside', 'vascular discolor'],
         'Panama Disease (Fusarium oxysporum)', 0.9),
    ],

    'Soybean': [
        (['soybean rust', 'asian rust', 'tan lesion underleaf', 'orange pustule'],
         'Soybean Rust (Phakopsora pachyrhizi)', 1.0),
        (['pod stem blight', 'stem blight', 'diaporthe'],
         'Pod and Stem Blight', 0.8),
        (['bacterial pustule', 'yellow halo spot', 'small pustule'],
         'Bacterial Pustule', 0.7),
        (['frogeye leaf spot', 'circular grey spot', 'frogeye'],
         'Frogeye Leaf Spot', 0.8),
        (['sudden death', 'interveinal chlorosis', 'premature leaf drop'],
         'Sudden Death Syndrome', 0.8),
    ],

    'Cowpea': [
        (['mosaic', 'cowpea mosaic', 'mottled', 'crinkled leaf'],
         'Cowpea Mosaic Virus', 1.0),
        (['brown blotch', 'septoria', 'tan lesion with dark border'],
         'Brown Blotch (Septoria)', 0.8),
        (['pod borer', 'maruca', 'webbed pod', 'borer in pod'],
         'Pod Borer (Maruca vitrata)', 0.9),
        (['striga', 'witchweed', 'purple weed at base', 'parasitic weed'],
         'Striga (Witchweed)', 1.0),
        (['root rot', 'damping off', 'seedling collapse'],
         'Root Rot / Damping Off', 0.8),
    ],

    'Millet': [
        (['downy mildew', 'green ear', 'white downy growth', 'systemic'],
         'Downy Mildew (Sclerospora graminicola)', 1.0),
        (['smut', 'head smut', 'black powder head', 'gall smut'],
         'Head Smut', 0.9),
        (['striga', 'witchweed', 'parasitic weed', 'purple flower weed'],
         'Striga Infestation', 1.0),
        (['blast', 'neck rot', 'grey lesion', 'pyricularia'],
         'Blast Disease', 0.8),
    ],

    'Sorghum': [
        (['striga', 'witchweed', 'parasitic weed', 'purple weed below plant'],
         'Striga (Witchweed)', 1.0),
        (['anthracnose', 'red stalk rot', 'salmon pustule', 'leaf anthracnose'],
         'Anthracnose (Colletotrichum)', 0.9),
        (['smut', 'covered kernel smut', 'loose kernel smut'],
         'Kernel Smut', 0.9),
        (['rust', 'orange pustule', 'sorghum rust'],
         'Common Rust', 0.8),
        (['grey leaf spot', 'exserohilum', 'tan rectangular lesion'],
         'Grey Leaf Spot', 0.8),
    ],
}


# ── Crop-specific treatment database ─────────────────────────────────────────

_CROP_DISEASE_INFO: Dict[str, List[Dict]] = {
    'Maize': [
        {'name': 'Fall Armyworm (Spodoptera frugiperda)', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Neem-based biopesticide or Coragen/Ampligo insecticide. Spray into the leaf whorl in the evening.',
         'prevention': 'Intercrop with legumes. Early planting before peak armyworm season. Use pheromone traps for monitoring.'},
        {'name': 'Maize Streak Virus (MSV)', 'type': 'Viral', 'risk': 'high',
         'treatment': 'No chemical cure. Remove and destroy infected plants. Control leafhopper vectors with Imidacloprid.',
         'prevention': 'Use MSV-tolerant varieties (Obatanpa, DK8031). Control leafhopper insects early.'},
        {'name': 'Grey Leaf Spot', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Mancozeb or Propiconazole fungicide at first sign of infection.',
         'prevention': 'Rotate crops. Use resistant hybrids. Remove crop debris after harvest.'},
        {'name': 'Northern Leaf Blight', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Azoxystrobin or Mancozeb when lesions first appear.',
         'prevention': 'Crop rotation. Resistant varieties. Proper field drainage.'},
        {'name': 'Common Rust', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Propiconazole or Tebuconazole fungicide.',
         'prevention': 'Use resistant hybrids. Avoid late planting.'},
        {'name': 'Stem Borer', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Carbofuran granules into the whorl. Biological control using Trichogramma parasitoids.',
         'prevention': 'Destroy crop residues after harvest. Intercrop with Push-Pull plants (Desmodium).'},
        {'name': 'Ear Rot / Aflatoxin Risk', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Harvest at correct moisture. Dry cobs to below 13% moisture immediately after harvest.',
         'prevention': 'Avoid delayed harvest. Store in well-ventilated cribs. Use aflatoxin-resistant varieties.'},
        {'name': 'Stalk Rot', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Harvest early when stalk rot appears. No effective in-field chemical treatment.',
         'prevention': 'Use resistant varieties. Balanced fertilisation — avoid excess nitrogen. Proper spacing.'},
    ],
    'Cassava': [
        {'name': 'Cassava Mosaic Disease (CMD)', 'type': 'Viral', 'risk': 'high',
         'treatment': 'Remove and destroy infected plants immediately. Plant only clean cuttings from disease-free mother plants.',
         'prevention': 'Use CMD-resistant varieties (TME 419, Agric). Control whitefly vectors with Neem oil or Imidacloprid.'},
        {'name': 'Cassava Brown Streak Disease (CBSD)', 'type': 'Viral', 'risk': 'high',
         'treatment': 'No cure. Remove infected plants. Use clean cuttings from certified sources.',
         'prevention': 'Use CBSD-tolerant varieties. Control whitefly. Regular scouting every 2 weeks.'},
        {'name': 'Root Rot (Phytophthora)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Improve soil drainage. Apply Metalaxyl soil drench. Remove infected plants.',
         'prevention': 'Avoid waterlogged soils. Well-drained ridges or mounds. Crop rotation.'},
        {'name': 'Cassava Anthracnose', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply copper-based fungicide. Remove and destroy infected stems.',
         'prevention': 'Use disease-free planting material. Avoid dense planting. Good field hygiene.'},
        {'name': 'Cassava Bacterial Blight', 'type': 'Bacterial', 'risk': 'high',
         'treatment': 'Remove infected plant parts. Apply copper-based bactericide. Use clean cutting tools.',
         'prevention': 'Use disease-free cuttings. Disinfect cutting tools with bleach between plants.'},
        {'name': 'Cassava Mealybug Infestation', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Neem oil or Imidacloprid. Biological control with parasitoid wasps (Anagyrus lopezi).',
         'prevention': 'Intercrop with cowpea. Monitor regularly. Remove volunteer plants.'},
    ],
    'Rice': [
        {'name': 'Rice Blast (Pyricularia oryzae)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Tricyclazole or Isoprothiolane at first symptoms. Avoid excess nitrogen fertiliser.',
         'prevention': 'Use blast-resistant varieties (NERICA). Balanced fertiliser. Proper water management.'},
        {'name': 'Rice Yellow Mottle Virus (RYMV)', 'type': 'Viral', 'risk': 'high',
         'treatment': 'No direct cure. Remove infected plants immediately. Control beetle and thrips vectors.',
         'prevention': 'Use resistant varieties. Control insects. Avoid infected seed.'},
        {'name': 'Sheath Blight (Rhizoctonia)', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Validamycin or Hexaconazole fungicide at tillering stage.',
         'prevention': 'Reduce plant density. Avoid excess nitrogen. Crop rotation.'},
        {'name': 'Bacterial Leaf Blight', 'type': 'Bacterial', 'risk': 'high',
         'treatment': 'Drain fields when possible. Apply copper-based bactericide. Reduce nitrogen input.',
         'prevention': 'Use resistant varieties. Avoid excess nitrogen. Manage flood water.'},
        {'name': 'Brown Planthopper', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Imidacloprid or Buprofezin insecticide at base of plant.',
         'prevention': 'Monitor regularly. Avoid excess nitrogen. Maintain beneficial insects.'},
        {'name': 'Rice Stem Borer', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Carbofuran granules at tillering. Use light traps for adults.',
         'prevention': 'Destroy stubble after harvest. Early uniform planting.'},
    ],
    'Tomato': [
        {'name': 'Late Blight (Phytophthora infestans)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Mancozeb, Metalaxyl, or Cymoxanil+Mancozeb every 7 days during rainy season.',
         'prevention': 'Avoid overhead irrigation. Improve airflow. Use resistant varieties. Crop rotation.'},
        {'name': 'Early Blight (Alternaria solani)', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Chlorothalonil or copper fungicide. Remove lower infected leaves.',
         'prevention': 'Mulch around plants. Avoid wetting leaves. Stake plants for airflow.'},
        {'name': 'Bacterial Wilt (Ralstonia solanacearum)', 'type': 'Bacterial', 'risk': 'high',
         'treatment': 'No effective chemical cure. Remove and destroy infected plants immediately.',
         'prevention': 'Crop rotation 3–4 years. Use resistant varieties. Improve soil drainage.'},
        {'name': 'Tomato Yellow Leaf Curl Virus (TYLCV)', 'type': 'Viral', 'risk': 'high',
         'treatment': 'Control whitefly vectors with Imidacloprid. Remove and destroy infected plants.',
         'prevention': 'Use TYLCV-resistant varieties. Insect-proof nursery. Neem oil for whitefly.'},
        {'name': 'Fusarium Wilt', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'No chemical cure once established. Remove infected plants. Use Trichoderma soil drench.',
         'prevention': 'Use resistant varieties. Soil solarisation. Proper crop rotation.'},
        {'name': 'Blossom End Rot (Calcium)', 'type': 'Physiological', 'risk': 'moderate',
         'treatment': 'Apply foliar calcium spray (calcium nitrate). Maintain even soil moisture.',
         'prevention': 'Consistent irrigation. Lime soil if acidic. Avoid excess nitrogen.'},
    ],
    'Cocoa': [
        {'name': 'Black Pod Disease (Phytophthora)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply copper-based fungicide (Ridomil Gold or Bordeaux mixture) monthly. Remove and destroy infected pods.',
         'prevention': 'Regular pod removal. Maintain proper canopy shade. Improve drainage.'},
        {'name': 'Cocoa Swollen Shoot Virus (CSSV)', 'type': 'Viral', 'risk': 'very high',
         'treatment': 'No cure. Uproot and burn infected trees. Replant with tolerant hybrid varieties.',
         'prevention': 'Use CSSV-tolerant hybrids. Control mealybug vectors. Buffer zones around infected farms.'},
        {'name': 'Cocoa Pod Borer (CPB)', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Frequent pod harvesting every 2 weeks. Apply Chlorpyrifos or Lambda-cyhalothrin.',
         'prevention': 'Harvest pods as soon as ripe. Bury or compost pod husks.'},
        {'name': 'Vascular Streak Dieback (VSD)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Prune diseased branches 30cm below infection. Apply copper fungicide on pruning cuts.',
         'prevention': 'Use disease-resistant planting material. Proper canopy management.'},
        {'name': 'Capsid Bug (Sahlbergella singularis)', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Chlorpyrifos or Cypermethrin in the evening when capsids feed.',
         'prevention': 'Regular monitoring. Maintain proper shade level. Early season treatment.'},
    ],
    'Groundnut': [
        {'name': 'Groundnut Rosette Virus', 'type': 'Viral', 'risk': 'very high',
         'treatment': 'No cure. Remove and destroy infected plants early. Control aphid vectors with Dimethoate.',
         'prevention': 'Use tolerant varieties (Azivivi). Early planting. Border rows of maize or sorghum.'},
        {'name': 'Early Leaf Spot (Cercospora arachidicola)', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Chlorothalonil or Mancozeb every 14 days from 30 days after planting.',
         'prevention': 'Crop rotation 2–3 years. Remove plant debris. Use resistant varieties.'},
        {'name': 'Late Leaf Spot', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Propiconazole or Tebuconazole. Start spraying at first sign.',
         'prevention': 'Crop rotation. Remove plant debris. Balanced fertilisation.'},
        {'name': 'Aflatoxin (Aspergillus flavus)', 'type': 'Fungal', 'risk': 'very high',
         'treatment': 'Harvest promptly. Dry pods immediately to below 10% moisture. Use aflatoxin binders in storage.',
         'prevention': 'Avoid drought stress at pod filling. Timely harvest. Proper drying and cool storage.'},
        {'name': 'Groundnut Rust', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Tebuconazole or Mancozeb. Spray undersides of leaves where pustules form.',
         'prevention': 'Use resistant varieties. Crop rotation. Early planting.'},
    ],
    'Yam': [
        {'name': 'Yam Mosaic Virus (YMV)', 'type': 'Viral', 'risk': 'high',
         'treatment': 'Use virus-free certified seed yam. Remove and destroy infected plants.',
         'prevention': 'Clean planting material from certified sources. Control aphid vectors.'},
        {'name': 'Yam Anthracnose', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply copper-based fungicide to tubers before planting. Avoid injury at harvest.',
         'prevention': 'Treat seed yam with fungicide. Proper storage. Crop rotation.'},
        {'name': 'Dry Rot (Sclerotium)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Treat seed yam with Mancozeb or Metalaxyl before planting.',
         'prevention': 'Certified seed yam. Cool ventilated storage. Avoid mechanical damage.'},
        {'name': 'Root-Knot Nematode', 'type': 'Pest', 'risk': 'moderate',
         'treatment': 'Apply Carbofuran nematicide. Soil solarisation before planting.',
         'prevention': 'Crop rotation. Use clean planting material. Avoid infected soil.'},
    ],
    'Pepper': [
        {'name': 'Bacterial Spot', 'type': 'Bacterial', 'risk': 'moderate',
         'treatment': 'Apply copper-based bactericide. Remove and destroy infected plant material.',
         'prevention': 'Use certified disease-free seeds. Avoid overhead watering. Crop rotation.'},
        {'name': 'Anthracnose / Fruit Rot', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Mancozeb or Azoxystrobin. Harvest before full maturity.',
         'prevention': 'Improve drainage. Avoid mechanical damage to fruits. Use clean seed.'},
        {'name': 'Pepper Mosaic Virus', 'type': 'Viral', 'risk': 'high',
         'treatment': 'Remove infected plants. Control aphid vectors with Imidacloprid or Neem oil.',
         'prevention': 'Use virus-free seeds. Control aphids. Physical barriers.'},
        {'name': 'Phytophthora Root Rot', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Metalaxyl soil drench. Improve drainage immediately.',
         'prevention': 'Well-drained soils or raised beds. Avoid overwatering.'},
    ],
    'Plantain': [
        {'name': 'Black Sigatoka (Mycosphaerella fijiensis)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Propiconazole or Azoxystrobin. Remove and destroy infected leaves.',
         'prevention': 'Remove diseased leaves regularly. Ensure adequate spacing and drainage.'},
        {'name': 'Banana Bunchy Top Virus (BBTV)', 'type': 'Viral', 'risk': 'very high',
         'treatment': 'Uproot and destroy infected plants immediately.',
         'prevention': 'Use virus-free planting material from certified sources. Control aphid vectors.'},
        {'name': 'Xanthomonas Wilt (BXW)', 'type': 'Bacterial', 'risk': 'very high',
         'treatment': 'No chemical cure. Remove and burn infected plants. Sterilise cutting tools.',
         'prevention': 'Use single-node cutting technique. Sterilise tools between plants with bleach.'},
        {'name': 'Banana Weevil (Cosmopolites sordidus)', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Use Chlorpyrifos or remove infested corms. Biological control with Beauveria bassiana.',
         'prevention': 'Plant trap crops. Remove corm debris. Use clean planting material.'},
    ],
    'Soybean': [
        {'name': 'Soybean Rust (Phakopsora pachyrhizi)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Azoxystrobin, Trifloxystrobin, or Tebuconazole at first sign.',
         'prevention': 'Use resistant varieties. Early planting. Crop rotation.'},
        {'name': 'Pod and Stem Blight', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Carbendazim or Thiophanate-methyl at pod fill stage.',
         'prevention': 'Use clean seed. Avoid delayed harvest. Crop rotation.'},
        {'name': 'Frogeye Leaf Spot', 'type': 'Fungal', 'risk': 'moderate',
         'treatment': 'Apply Thiophanate-methyl or Azoxystrobin.',
         'prevention': 'Use resistant varieties. Crop rotation. Remove debris.'},
    ],
    'Cowpea': [
        {'name': 'Cowpea Mosaic Virus', 'type': 'Viral', 'risk': 'high',
         'treatment': 'Remove infected plants. Control aphid and beetle vectors with Dimethoate.',
         'prevention': 'Use resistant varieties. Control insect vectors. Crop rotation.'},
        {'name': 'Pod Borer (Maruca vitrata)', 'type': 'Pest', 'risk': 'high',
         'treatment': 'Apply Cypermethrin or Dimethoate at flowering.',
         'prevention': 'Early planting. Monitor flower stage closely. Use resistant varieties.'},
        {'name': 'Striga (Witchweed)', 'type': 'Parasitic', 'risk': 'high',
         'treatment': 'Hand-weed before Striga flowers. Use Imazapyr-treated seed.',
         'prevention': 'Crop rotation with non-host crops. Striga-resistant cowpea varieties.'},
    ],
    'Millet': [
        {'name': 'Downy Mildew (Sclerospora graminicola)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Metalaxyl or Cymoxanil. Remove infected plants immediately.',
         'prevention': 'Use resistant varieties. Treat seed with Metalaxyl. Crop rotation.'},
        {'name': 'Head Smut', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Remove smut balls before they open. Treat seed with systemic fungicide.',
         'prevention': 'Use smut-free seed. Treat seed with Carboxin+Thiram.'},
        {'name': 'Striga Infestation', 'type': 'Parasitic', 'risk': 'very high',
         'treatment': 'Hand-pull before Striga seeds set. Apply Imazapyr or 2,4-D.',
         'prevention': 'Crop rotation. Striga-resistant varieties. Intercrop with legumes.'},
    ],
    'Sorghum': [
        {'name': 'Striga (Witchweed)', 'type': 'Parasitic', 'risk': 'very high',
         'treatment': 'Early hand-weeding. Imazapyr-treated seed.',
         'prevention': 'Crop rotation with legumes. Striga-resistant sorghum varieties.'},
        {'name': 'Anthracnose (Colletotrichum)', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Apply Propiconazole. Remove infected stalk residues after harvest.',
         'prevention': 'Resistant varieties. Crop rotation.'},
        {'name': 'Kernel Smut', 'type': 'Fungal', 'risk': 'high',
         'treatment': 'Remove smut galls. Treat seed with Carboxin fungicide.',
         'prevention': 'Use smut-free seed. Crop rotation.'},
    ],
}

# GDD thresholds per crop
_GDD_TO_HARVEST: Dict[str, int] = {
    'Maize': 1200, 'Rice': 1400, 'Tomato': 900, 'Pepper': 1100,
    'Cassava': 3000, 'Yam': 2500, 'Groundnut': 1300, 'Soybean': 1300,
    'Cowpea': 1000, 'Millet': 1000, 'Sorghum': 1200, 'Cocoa': 0,
    'Plantain': 1800, 'Cocoyam': 2000, 'Sweet Potato': 1400, 'Okra': 800,
    'Banana': 2000,
}


class AdvisoryEngine:
    """
    Voting-based advisory engine for Ghana crop disease diagnosis.

    Each symptom keyword votes for a specific disease. The disease with
    the highest total vote score is returned as the diagnosis. Confidence
    reflects how many of the expected keywords for that disease were matched.
    """

    def diagnose(self,
                 crop: str,
                 region: str,
                 symptoms: Optional[str] = None,
                 observed_disease: Optional[str] = None,
                 weather: Optional[dict] = None,
                 quality_score: Optional[float] = None,
                 diary_summary: Optional[dict] = None) -> dict:

        norm_crop   = _normalise_crop(crop)
        symptom_txt = _normalise_text(symptoms)
        disease_txt = _normalise_text(observed_disease)
        combined    = symptom_txt + ' ' + disease_txt

        evidence: List[str] = []

        # ── Step 1: Vote on diseases from symptom keywords ────────────────────
        disease_name, confidence, matched_keywords = self._vote_diagnosis(
            norm_crop, combined
        )

        for kw in matched_keywords:
            evidence.append(f'symptom_matched: {kw}')

        # ── Step 2: Directly reported disease overrides low-confidence match ──
        if observed_disease and (confidence < 0.5 or disease_name == 'Unknown Stress'):
            reported = observed_disease.strip().title()
            treatment, prevention = self._lookup_treatment(norm_crop, reported)
            if treatment:
                disease_name = reported
                confidence   = 0.75
                evidence.insert(0, f'farmer_reported: {reported}')
            else:
                evidence.insert(0, f'farmer_reported: {reported}')
                disease_name = reported
                confidence   = max(confidence, 0.55)

        # ── Step 3: Disease risk score ─────────────────────────────────────────
        disease_risk = confidence * 0.80  # scale confidence to risk range

        # Diary signals boost risk
        if diary_summary:
            pest_evt    = int(diary_summary.get('pest_events', 0) or 0)
            disease_evt = int(diary_summary.get('disease_events', 0) or 0)
            if pest_evt:
                disease_risk = min(1.0, disease_risk + pest_evt * 0.04)
                evidence.append(f'diary_pest_events: {pest_evt}')
            if disease_evt:
                disease_risk = min(1.0, disease_risk + disease_evt * 0.05)
                evidence.append(f'diary_disease_events: {disease_evt}')

        if quality_score is not None and float(quality_score) <= 4.0:
            disease_risk = min(1.0, disease_risk + 0.08)
            evidence.append('low_quality_score')

        # ── Step 4: Weather risk ───────────────────────────────────────────────
        weather_risk = self._weather_risk(weather)
        if weather_risk > 0.05:
            evidence.append(f'weather_risk: {weather_risk:.2f}')

        disease_risk = round(min(1.0, disease_risk + weather_risk * 0.3), 3)

        # ── Step 5: Yield impact ───────────────────────────────────────────────
        yield_factor = round(max(0.60, 1.05 - disease_risk * 0.45), 3)

        # ── Step 6: Treatment lookup ───────────────────────────────────────────
        treatment, prevention = self._lookup_treatment(norm_crop, disease_name)

        quality_note = ''
        if quality_score is not None:
            qs = float(quality_score)
            if qs <= 4.0:
                quality_note = 'Low quality score suggests late-season stress or disease damage.'
            elif qs >= 8.5:
                quality_note = 'High quality score indicates healthy crop and good management.'

        return {
            'crop':                     crop,
            'region':                   region,
            'disease_name':             disease_name,
            'confidence':               round(confidence, 2),
            'disease_risk':             disease_risk,
            'weather_risk':             round(weather_risk, 3),
            'quality_score':            quality_score,
            'quality_note':             quality_note,
            'yield_factor':             yield_factor,
            'treatment':                treatment,
            'prevention':               prevention,
            'evidence':                 evidence,
            'common_diseases_for_crop': self._disease_names(norm_crop),
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

        tips: List[str] = []
        summary_parts: List[str] = [f'Crop: {crop}. Region: {region}.']

        if disease_risk >= 0.70:
            summary_parts.append('HIGH disease/pest risk — immediate action required.')
            tips.append('Inspect every plant row daily. Isolate visibly affected plants.')
            tips.append('Apply crop-specific treatment immediately — delay worsens spread.')
            if treatment:
                tips.append(f'Recommended treatment: {treatment}')
        elif disease_risk >= 0.40:
            summary_parts.append('Moderate risk — preventive action recommended.')
            tips.append('Scout fields at least twice per week for early symptoms.')
            tips.append('Apply preventive fungicide/insecticide as per MoFA guidance.')
            if treatment:
                tips.append(f'Suggested treatment: {treatment}')
        else:
            summary_parts.append('Low disease risk — routine monitoring sufficient.')
            tips.append('Continue routine field scouting once per week.')
            tips.append('Maintain field hygiene — remove crop debris and volunteer plants.')

        if prevention:
            tips.append(f'Prevention: {prevention}')

        if weather_risk >= 0.50:
            summary_parts.append('Weather conditions favour disease spread.')
            tips.append('Delay foliar spraying until rain stops and wind is calm.')
            tips.append('Check drainage — waterlogged soils rapidly cause root rot.')
        elif weather_risk >= 0.20:
            tips.append('Humid or rainy weather increases fungal disease pressure. Scout more frequently.')

        if quality_score is not None:
            qs = float(quality_score)
            if qs >= 8.0:
                tips.append('Excellent quality — target premium buyers and agro-processors.')
            elif qs <= 4.0:
                tips.append('Poor quality — review post-harvest storage and handling immediately.')
                tips.append('Check for aflatoxin risk if storing in humid or warm conditions.')

        if diary_summary:
            rain_mm = float(diary_summary.get('total_rainfall_mm') or 0)
            fert_n  = int(diary_summary.get('fertilizer_applications') or 0)
            irr     = int(diary_summary.get('irrigation_days') or 0)
            if rain_mm < 200:
                tips.append(f'Season rainfall is low ({rain_mm:.0f} mm). Supplement with irrigation at flowering.')
            if fert_n == 0:
                tips.append('No fertiliser recorded. Consider top-dressing NPK if still in vegetative stage.')
            if irr > 10:
                tips.append('Frequent irrigation noted — verify soil drainage to prevent waterlogging.')

        return {
            'summary':     ' '.join(summary_parts),
            'tips':        tips,
            'risk_level':  ('high' if disease_risk >= 0.70 else 'moderate' if disease_risk >= 0.40 else 'low'),
            'disease_risk': round(disease_risk, 3),
            'weather_risk': round(weather_risk, 3),
        }

    def estimate_days_to_harvest(self, crop: str, accumulated_gdd: float,
                                 avg_gdd_per_day: float) -> Optional[int]:
        norm = _normalise_crop(crop)
        needed = _GDD_TO_HARVEST.get(norm)
        if needed is None or needed == 0:
            return None
        remaining = max(0.0, needed - float(accumulated_gdd))
        if avg_gdd_per_day <= 0:
            return None
        return int(round(remaining / avg_gdd_per_day))

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _vote_diagnosis(self, crop: str, text: str
                        ) -> Tuple[str, float, List[str]]:
        """
        Vote on the most likely disease using crop-specific symptom maps.
        Returns (disease_name, confidence [0-1], matched_keywords).
        """
        vote_map: Dict[str, float] = {}  # disease → total vote score
        keyword_map: Dict[str, List[str]] = {}  # disease → matched keywords
        max_possible: Dict[str, float] = {}  # disease → max possible score

        crop_rules = _CROP_SYMPTOM_VOTES.get(crop, [])

        for keyword_list, disease, weight in crop_rules:
            max_possible[disease] = max_possible.get(disease, 0) + weight
            for kw in keyword_list:
                if kw in text:
                    vote_map[disease] = vote_map.get(disease, 0) + weight
                    keyword_map.setdefault(disease, []).append(kw)
                    break  # one match per rule is enough to trigger the vote

        if not vote_map:
            return 'Unknown Stress — Consult extension officer', 0.0, []

        best_disease = max(vote_map, key=vote_map.get)
        raw_score    = vote_map[best_disease]
        max_score    = max_possible.get(best_disease, 1.0)
        confidence   = min(1.0, raw_score / max_score)

        return best_disease, confidence, keyword_map.get(best_disease, [])

    def _lookup_treatment(self, crop: str, disease_name: str) -> Tuple[str, str]:
        disease_lower = disease_name.lower()
        diseases = _CROP_DISEASE_INFO.get(crop, [])
        for d in diseases:
            if d['name'].lower() in disease_lower or disease_lower in d['name'].lower():
                return d.get('treatment', ''), d.get('prevention', '')
        # Partial match across all crops as fallback
        for crop_diseases in _CROP_DISEASE_INFO.values():
            for d in crop_diseases:
                dname = d['name'].lower()
                if any(word in disease_lower for word in dname.split() if len(word) > 4):
                    return d.get('treatment', ''), d.get('prevention', '')
        return '', ''

    def _disease_names(self, crop: str) -> List[str]:
        diseases = _CROP_DISEASE_INFO.get(crop, [])
        if diseases:
            return [d['name'] for d in diseases]
        return ['Consult your local MoFA extension officer for crop-specific disease advice.']

    def _weather_risk(self, weather) -> float:
        if not weather:
            return 0.0
        if isinstance(weather, dict):
            humidity = float(weather.get('humidity', 0) or 0)
            rainfall = float(weather.get('rainfallNext24hMm') or weather.get('rainfall_mm') or 0)
            temp = float(weather.get('temperatureC') or weather.get('temp_c') or 25)
            risk = 0.0
            if humidity >= 85 or rainfall >= 20:
                risk += 0.35
            elif humidity >= 75 or rainfall >= 10:
                risk += 0.22
            elif humidity >= 65 or rainfall >= 5:
                risk += 0.10
            if temp >= 36 or temp <= 12:
                risk += 0.12
            return min(1.0, risk)
        return 0.0
