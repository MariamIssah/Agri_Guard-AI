from typing import Dict, Optional


def clean_disease_label(raw_label: str) -> str:
    label = raw_label.replace('___', ' - ').replace('_', ' ')
    label = ' '.join(label.split())
    return label.title()


def parse_disease_label(raw_label: str) -> Dict[str, Optional[str]]:
    normalized = clean_disease_label(raw_label)
    if ' - ' in normalized:
        crop, disease = normalized.split(' - ', 1)
    else:
        crop = None
        disease = normalized
    return {
        'raw_label': raw_label,
        'crop': crop,
        'disease_name': disease,
        'normalized_label': normalized,
    }


def get_disease_details(raw_label: str) -> Dict[str, str]:
    parsed = parse_disease_label(raw_label)
    disease = parsed['disease_name']
    crop = parsed['crop']

    disease_map = {
        'Healthy': {
            'disease_name': 'Healthy',
            'disease_category': 'No Disease',
            'description': 'The crop appears healthy with no visible disease symptoms.',
            'treatment': ['Continue good crop management and monitor regularly.'],
            'prevention': ['Keep fields clean, use resistant varieties, and scout often.'],
        },
        'Powdery Mildew': {
            'disease_name': 'Powdery Mildew',
            'disease_category': 'Fungal Disease',
            'description': 'A fungal infection that forms white powdery patches on leaves and stems.',
            'treatment': [
                'Spray sulfur-based fungicides or neem oil.',
                'Remove infected leaves and improve air circulation.',
            ],
            'prevention': [
                'Avoid overhead irrigation and maintain plant spacing.',
                'Plant resistant varieties when available.',
            ],
        },
        'Common Rust': {
            'disease_name': 'Common Rust',
            'disease_category': 'Fungal Disease',
            'description': 'Rust pustules appear on maize leaves, reducing photosynthesis.',
            'treatment': [
                'Apply copper-based or systemic fungicides.',
                'Remove severely infected leaves and avoid dense planting.',
            ],
            'prevention': [
                'Rotate crops and avoid planting maize continuously in the same field.',
                'Use resistant maize varieties when possible.',
            ],
        },
        'Northern Leaf Blight': {
            'disease_name': 'Northern Leaf Blight',
            'disease_category': 'Fungal Disease',
            'description': 'Long, grayish lesions develop on leaves, reducing yield potential.',
            'treatment': [
                'Apply appropriate fungicides promptly.',
                'Destroy crop residues after harvest.',
            ],
            'prevention': [
                'Rotate crops and use resistant hybrids.',
                'Plant in well-drained areas with good airflow.',
            ],
        },
        'Cercospora Leaf Spot Gray Leaf Spot': {
            'disease_name': 'Gray Leaf Spot',
            'disease_category': 'Fungal Disease',
            'description': 'Gray rectangular lesions caused by Cercospora fungi appear on leaves.',
            'treatment': [
                'Apply fungicides with active ingredients proven effective against Cercospora.',
                'Remove and destroy infected plant residue.',
            ],
            'prevention': [
                'Rotate crops and plant resistant varieties.',
                'Avoid excess nitrogen fertilization.',
            ],
        },
        'Bacterial Spot': {
            'disease_name': 'Bacterial Spot',
            'disease_category': 'Bacterial Disease',
            'description': 'Dark, water-soaked spots appear on leaves and fruit.',
            'treatment': [
                'Use bactericidal sprays such as copper formulations.',
                'Remove infected leaves and manage irrigation carefully.',
            ],
            'prevention': [
                'Avoid overhead watering and use clean seed material.',
                'Practice crop sanitation and rotation.',
            ],
        },
        'Late Blight': {
            'disease_name': 'Late Blight',
            'disease_category': 'Fungal-Like Disease',
            'description': 'Rapid, dark lesions on leaves and tubers often associated with wet weather.',
            'treatment': [
                'Apply fungicides promptly before disease spreads.',
                'Remove infected plants and dispose of debris safely.',
            ],
            'prevention': [
                'Plant certified disease-free seed and rotate crops.',
                'Ensure good drainage and avoid wet foliage.',
            ],
        },
        'Early Blight': {
            'disease_name': 'Early Blight',
            'disease_category': 'Fungal Disease',
            'description': 'Target-shaped leaf spots reduce yield and may spread rapidly under humid conditions.',
            'treatment': [
                'Use fungicides and remove affected foliage.',
                'Improve air circulation in the crop canopy.',
            ],
            'prevention': [
                'Rotate crops and plant resistant varieties.',
                'Avoid overhead irrigation during evening hours.',
            ],
        },
        'Tomato Mosaic Virus': {
            'disease_name': 'Tomato Mosaic Virus',
            'disease_category': 'Viral Disease',
            'description': 'Mottled leaf patterns and stunted growth caused by a viral infection.',
            'treatment': [
                'Remove infected plants immediately.',
                'Disinfect tools and control aphid vectors.',
            ],
            'prevention': [
                'Use virus-free seeds and resistant varieties.',
                'Practice strict sanitation and crop rotation.',
            ],
        },
        'Tomato Yellow Leaf Curl Virus': {
            'disease_name': 'Tomato Yellow Leaf Curl Virus',
            'disease_category': 'Viral Disease',
            'description': 'Leaves curl upward and yellow, often spread by whiteflies.',
            'treatment': [
                'Remove infected plants and control whitefly populations.',
                'Use insect-proof netting if possible.',
            ],
            'prevention': [
                'Plant resistant varieties and control whitefly vectors.',
                'Destroy infected plants quickly to reduce spread.',
            ],
        },
        'Spider Mites Two Spotted Spider Mite': {
            'disease_name': 'Spider Mite Infestation',
            'disease_category': 'Pest Damage',
            'description': 'Fine webbing and stippled leaves indicate spider mite attack.',
            'treatment': [
                'Apply miticides or insecticidal soaps.',
                'Increase humidity and spray with water to dislodge mites.',
            ],
            'prevention': [
                'Monitor regularly and avoid plant stress.',
                'Use predatory mites where available.',
            ],
        },
    }

    for key, value in disease_map.items():
        if key.lower() in disease.lower():
            result = {**value}
            result['crop'] = crop
            return result

    # fallback generic advice for unknown diseases
    return {
        'crop': crop,
        'disease_name': disease,
        'disease_category': 'Unknown / Other',
        'description': 'The model detected a disease pattern, but the diagnosis is not mapped to a specific advisory yet.',
        'treatment': ['Review the crop and symptoms with a local agricultural expert.', 'Use integrated pest and disease management practices.'],
        'prevention': ['Keep detailed records, rotate crops, and maintain good crop hygiene.'],
    }
