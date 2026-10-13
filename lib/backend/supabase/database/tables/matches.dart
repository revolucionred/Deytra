import '../database.dart';

class MatchesTable extends SupabaseTable<MatchesRow> {
  @override
  String get tableName => 'matches';

  @override
  MatchesRow createRow(Map<String, dynamic> data) => MatchesRow(data);
}

class MatchesRow extends SupabaseDataRow {
  MatchesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchesTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get sourceIntentId => getField<String>('source_intent_id')!;
  set sourceIntentId(String value) =>
      setField<String>('source_intent_id', value);

  String? get targetIntentId => getField<String>('target_intent_id');
  set targetIntentId(String? value) =>
      setField<String>('target_intent_id', value);

  String? get targetEntityId => getField<String>('target_entity_id');
  set targetEntityId(String? value) =>
      setField<String>('target_entity_id', value);

  String? get matchSource => getField<String>('match_source');
  set matchSource(String? value) => setField<String>('match_source', value);

  String? get resultType => getField<String>('result_type');
  set resultType(String? value) => setField<String>('result_type', value);

  String? get title => getField<String>('title');
  set title(String? value) => setField<String>('title', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);

  String? get externalUrl => getField<String>('external_url');
  set externalUrl(String? value) => setField<String>('external_url', value);

  double? get score => getField<double>('score');
  set score(double? value) => setField<double>('score', value);

  double? get distanceKm => getField<double>('distance_km');
  set distanceKm(double? value) => setField<double>('distance_km', value);

  String? get reason => getField<String>('reason');
  set reason(String? value) => setField<String>('reason', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  dynamic? get metadata => getField<dynamic>('metadata');
  set metadata(dynamic? value) => setField<dynamic>('metadata', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  DateTime? get updatedAt => getField<DateTime>('updated_at');
  set updatedAt(DateTime? value) => setField<DateTime>('updated_at', value);
}
