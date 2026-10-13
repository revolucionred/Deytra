import '../database.dart';

class ConnectionsTable extends SupabaseTable<ConnectionsRow> {
  @override
  String get tableName => 'connections';

  @override
  ConnectionsRow createRow(Map<String, dynamic> data) => ConnectionsRow(data);
}

class ConnectionsRow extends SupabaseDataRow {
  ConnectionsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ConnectionsTable();

  String? get id => getField<String>('id');
  set id(String? value) => setField<String>('id', value);

  String get matchId => getField<String>('match_id')!;
  set matchId(String value) => setField<String>('match_id', value);

  String? get requesterEntityId => getField<String>('requester_entity_id');
  set requesterEntityId(String? value) =>
      setField<String>('requester_entity_id', value);

  String? get recipientEntityId => getField<String>('recipient_entity_id');
  set recipientEntityId(String? value) =>
      setField<String>('recipient_entity_id', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);

  String? get introMessage => getField<String>('intro_message');
  set introMessage(String? value) => setField<String>('intro_message', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  DateTime? get respondedAt => getField<DateTime>('responded_at');
  set respondedAt(DateTime? value) => setField<DateTime>('responded_at', value);

  DateTime? get updatedAt => getField<DateTime>('updated_at');
  set updatedAt(DateTime? value) => setField<DateTime>('updated_at', value);
}
