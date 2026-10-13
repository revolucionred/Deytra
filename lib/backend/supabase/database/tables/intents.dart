import '../database.dart';

class IntentsTable extends SupabaseTable<IntentsRow> {
  @override
  String get tableName => 'intents';

  @override
  IntentsRow createRow(Map<String, dynamic> data) => IntentsRow(data);
}

class IntentsRow extends SupabaseDataRow {
  IntentsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => IntentsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get entityId => getField<String>('entity_id')!;
  set entityId(String value) => setField<String>('entity_id', value);

  String? get intentType => getField<String>('intent_type');
  set intentType(String? value) => setField<String>('intent_type', value);

  String? get rawText => getField<String>('raw_text');
  set rawText(String? value) => setField<String>('raw_text', value);

  String? get title => getField<String>('title');
  set title(String? value) => setField<String>('title', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  String? get city => getField<String>('city');
  set city(String? value) => setField<String>('city', value);

  String? get countryCode => getField<String>('country_code');
  set countryCode(String? value) => setField<String>('country_code', value);

  double? get latitude => getField<double>('latitude');
  set latitude(double? value) => setField<double>('latitude', value);

  double? get longitude => getField<double>('longitude');
  set longitude(double? value) => setField<double>('longitude', value);

  double? get radiusKm => getField<double>('radius_km');
  set radiusKm(double? value) => setField<double>('radius_km', value);

  String? get locationImportance => getField<String>('location_importance');
  set locationImportance(String? value) =>
      setField<String>('location_importance', value);

  bool? get remoteOk => getField<bool>('remote_ok');
  set remoteOk(bool? value) => setField<bool>('remote_ok', value);

  String? get category => getField<String>('category');
  set category(String? value) => setField<String>('category', value);

  dynamic? get metadata => getField<dynamic>('metadata');
  set metadata(dynamic? value) => setField<dynamic>('metadata', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  DateTime? get updatedAt => getField<DateTime>('updated_at');
  set updatedAt(DateTime? value) => setField<DateTime>('updated_at', value);
}
