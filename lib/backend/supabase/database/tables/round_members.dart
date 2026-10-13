import '../database.dart';

class RoundMembersTable extends SupabaseTable<RoundMembersRow> {
  @override
  String get tableName => 'round_members';

  @override
  RoundMembersRow createRow(Map<String, dynamic> data) => RoundMembersRow(data);
}

class RoundMembersRow extends SupabaseDataRow {
  RoundMembersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => RoundMembersTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get roundId => getField<String>('round_id')!;
  set roundId(String value) => setField<String>('round_id', value);

  String? get entityId => getField<String>('entity_id');
  set entityId(String? value) => setField<String>('entity_id', value);

  String? get role => getField<String>('role');
  set role(String? value) => setField<String>('role', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  DateTime? get joinedAt => getField<DateTime>('joined_at');
  set joinedAt(DateTime? value) => setField<DateTime>('joined_at', value);
}
