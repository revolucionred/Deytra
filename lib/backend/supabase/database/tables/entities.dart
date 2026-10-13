import '../database.dart';

class EntitiesTable extends SupabaseTable<EntitiesRow> {
  @override
  String get tableName => 'entities';

  @override
  EntitiesRow createRow(Map<String, dynamic> data) => EntitiesRow(data);
}

class EntitiesRow extends SupabaseDataRow {
  EntitiesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EntitiesTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get ownerProfileId => getField<String>('owner_profile_id')!;
  set ownerProfileId(String value) =>
      setField<String>('owner_profile_id', value);

  String? get entityType => getField<String>('entity_type');
  set entityType(String? value) => setField<String>('entity_type', value);

  String? get name => getField<String>('name');
  set name(String? value) => setField<String>('name', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  String? get avatarUrl => getField<String>('avatar_url');
  set avatarUrl(String? value) => setField<String>('avatar_url', value);

  String? get websiteUrl => getField<String>('website_url');
  set websiteUrl(String? value) => setField<String>('website_url', value);

  String? get instagramUrl => getField<String>('instagram_url');
  set instagramUrl(String? value) => setField<String>('instagram_url', value);

  String? get city => getField<String>('city');
  set city(String? value) => setField<String>('city', value);

  String? get countryCode => getField<String>('country_code');
  set countryCode(String? value) => setField<String>('country_code', value);

  double? get latitude => getField<double>('latitude');
  set latitude(double? value) => setField<double>('latitude', value);

  double? get longitude => getField<double>('longitude');
  set longitude(double? value) => setField<double>('longitude', value);

  bool? get isVerified => getField<bool>('is_verified');
  set isVerified(bool? value) => setField<bool>('is_verified', value);

  bool? get isActive => getField<bool>('is_active');
  set isActive(bool? value) => setField<bool>('is_active', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
