import '../database.dart';

class RoundsTable extends SupabaseTable<RoundsRow> {
  @override
  String get tableName => 'rounds';

  @override
  RoundsRow createRow(Map<String, dynamic> data) => RoundsRow(data);
}

class RoundsRow extends SupabaseDataRow {
  RoundsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => RoundsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get ownerEntityId => getField<String>('owner_entity_id')!;
  set ownerEntityId(String value) => setField<String>('owner_entity_id', value);

  String? get name => getField<String>('name');
  set name(String? value) => setField<String>('name', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  String? get imageUrl => getField<String>('image_url');
  set imageUrl(String? value) => setField<String>('image_url', value);

  String? get roundType => getField<String>('round_type');
  set roundType(String? value) => setField<String>('round_type', value);

  String? get visibility => getField<String>('visibility');
  set visibility(String? value) => setField<String>('visibility', value);

  String? get accessCode => getField<String>('access_code');
  set accessCode(String? value) => setField<String>('access_code', value);

  String? get city => getField<String>('city');
  set city(String? value) => setField<String>('city', value);

  String? get countryCode => getField<String>('country_code');
  set countryCode(String? value) => setField<String>('country_code', value);

  DateTime? get startsAt => getField<DateTime>('starts_at');
  set startsAt(DateTime? value) => setField<DateTime>('starts_at', value);

  DateTime? get endsAt => getField<DateTime>('ends_at');
  set endsAt(DateTime? value) => setField<DateTime>('ends_at', value);

  bool? get isActive => getField<bool>('is_active');
  set isActive(bool? value) => setField<bool>('is_active', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
