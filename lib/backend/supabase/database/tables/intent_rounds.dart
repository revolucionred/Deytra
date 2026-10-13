import '../database.dart';

class IntentRoundsTable extends SupabaseTable<IntentRoundsRow> {
  @override
  String get tableName => 'intent_rounds';

  @override
  IntentRoundsRow createRow(Map<String, dynamic> data) => IntentRoundsRow(data);
}

class IntentRoundsRow extends SupabaseDataRow {
  IntentRoundsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => IntentRoundsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get intentId => getField<String>('intent_id')!;
  set intentId(String value) => setField<String>('intent_id', value);

  String? get roundId => getField<String>('round_id');
  set roundId(String? value) => setField<String>('round_id', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
