// Represents a pet stored in Firebase.
class Pet {
  final String? id;
  final String name;
  final String type;
  final String breed;
  final String birthday;
  final double weight;
  final double length;
  final double height;
  final String collarId;
  final String ownerId;
  final String? imageBase64;

  Pet({
    this.id,
    required this.name,
    required this.type,
    required this.breed,
    required this.birthday,
    required this.weight,
    required this.length,
    required this.height,
    required this.collarId,
    required this.ownerId,
    this.imageBase64,
  });

  // Converts this pet to a map for Firebase storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'breed': breed,
      'birthday': birthday,
      'weight': weight,
      'length': length,
      'height': height,
      'collarId': collarId,
      'ownerId': ownerId,
      'imageBase64': imageBase64,
    };
  }

  // Creates a Pet object from Firebase document data.
  factory Pet.fromMap(Map<String, dynamic> map, String docId) {
    return Pet(
      id: docId,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      breed: map['breed'] ?? '',
      birthday: map['birthday'] ?? '',
      weight: (map['weight'] ?? 0.0).toDouble(),
      length: (map['length'] ?? 0.0).toDouble(),
      height: (map['height'] ?? 0.0).toDouble(),
      collarId: map['collarId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      imageBase64: map['imageBase64'],
    );
  }
}
