import 'package:drift/drift.dart';

part 'database.g.dart';

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get contentBlocks => text().nullable()();
  TextColumn get category => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().nullable()();
  BoolColumn get isAiGenerated =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get tagId => text().references(Tags, #id)();
  RealColumn get confidence => real().nullable()();
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

class NoteLinks extends Table {
  TextColumn get sourceId => text().references(Notes, #id)();
  TextColumn get targetId => text().references(Notes, #id)();
  TextColumn get linkType => text()(); // 'wikilink', 'ai_suggestion', 'backlink'
  TextColumn get context => text().nullable()();
  RealColumn get confidence => real().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId, targetId, linkType};
}

@DriftDatabase(tables: [Notes, Tags, NoteTags, NoteLinks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // FTS5 virtual table for full-text search
        await customStatement('''
          CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            title, content,
            content=notes,
            content_rowid=rowid,
            tokenize='unicode61'
          )
        ''');

        // Triggers to keep FTS index in sync
        await customStatement('''
          CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
            INSERT INTO notes_fts(rowid, title, content)
            VALUES (new.rowid, new.title, new.content);
          END
        ''');
        await customStatement('''
          CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, content)
            VALUES ('delete', old.rowid, old.title, old.content);
          END
        ''');
        await customStatement('''
          CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, content)
            VALUES ('delete', old.rowid, old.title, old.content);
            INSERT INTO notes_fts(rowid, title, content)
            VALUES (new.rowid, new.title, new.content);
          END
        ''');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future schema migrations go here.
        // Example:
        // if (from < 2) {
        //   await m.addColumn(notes, notes.someNewColumn);
        // }
        // if (from < 3) {
        //   await m.createTable(someNewTable);
        // }
      },
    );
  }
}
