// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sticker_pack.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetStickerPackCollection on Isar {
  IsarCollection<StickerPack> get stickerPacks => this.collection();
}

const StickerPackSchema = CollectionSchema(
  name: r'StickerPack',
  id: 5014667020329468921,
  properties: {
    r'createdAtMillis': PropertySchema(
      id: 0,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'identifier': PropertySchema(
      id: 1,
      name: r'identifier',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 2, name: r'name', type: IsarType.string),
    r'publisher': PropertySchema(
      id: 3,
      name: r'publisher',
      type: IsarType.string,
    ),
    r'stickerPaths': PropertySchema(
      id: 4,
      name: r'stickerPaths',
      type: IsarType.stringList,
    ),
    r'stickers': PropertySchema(
      id: 5,
      name: r'stickers',
      type: IsarType.objectList,
      target: r'StickerRecord',
    ),
    r'trayIconBytes': PropertySchema(
      id: 6,
      name: r'trayIconBytes',
      type: IsarType.byteList,
    ),
    r'updatedAtMillis': PropertySchema(
      id: 7,
      name: r'updatedAtMillis',
      type: IsarType.long,
    ),
  },
  estimateSize: _stickerPackEstimateSize,
  serialize: _stickerPackSerialize,
  deserialize: _stickerPackDeserialize,
  deserializeProp: _stickerPackDeserializeProp,
  idName: r'id',
  indexes: {
    r'identifier': IndexSchema(
      id: -1091831983288130400,
      name: r'identifier',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'identifier',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'StickerRecord': StickerRecordSchema},
  getId: _stickerPackGetId,
  getLinks: _stickerPackGetLinks,
  attach: _stickerPackAttach,
  version: '3.1.0+1',
);

int _stickerPackEstimateSize(
  StickerPack object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.identifier.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.publisher.length * 3;
  bytesCount += 3 + object.stickerPaths.length * 3;
  {
    for (var i = 0; i < object.stickerPaths.length; i++) {
      final value = object.stickerPaths[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.stickers.length * 3;
  {
    final offsets = allOffsets[StickerRecord]!;
    for (var i = 0; i < object.stickers.length; i++) {
      final value = object.stickers[i];
      bytesCount += StickerRecordSchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.trayIconBytes.length;
  return bytesCount;
}

void _stickerPackSerialize(
  StickerPack object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.createdAtMillis);
  writer.writeString(offsets[1], object.identifier);
  writer.writeString(offsets[2], object.name);
  writer.writeString(offsets[3], object.publisher);
  writer.writeStringList(offsets[4], object.stickerPaths);
  writer.writeObjectList<StickerRecord>(
    offsets[5],
    allOffsets,
    StickerRecordSchema.serialize,
    object.stickers,
  );
  writer.writeByteList(offsets[6], object.trayIconBytes);
  writer.writeLong(offsets[7], object.updatedAtMillis);
}

StickerPack _stickerPackDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StickerPack();
  object.createdAtMillis = reader.readLong(offsets[0]);
  object.id = id;
  object.identifier = reader.readString(offsets[1]);
  object.name = reader.readString(offsets[2]);
  object.publisher = reader.readString(offsets[3]);
  object.stickerPaths = reader.readStringList(offsets[4]) ?? [];
  object.stickers =
      reader.readObjectList<StickerRecord>(
        offsets[5],
        StickerRecordSchema.deserialize,
        allOffsets,
        StickerRecord(),
      ) ??
      [];
  object.trayIconBytes = reader.readByteList(offsets[6]) ?? [];
  object.updatedAtMillis = reader.readLong(offsets[7]);
  return object;
}

P _stickerPackDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringList(offset) ?? []) as P;
    case 5:
      return (reader.readObjectList<StickerRecord>(
                offset,
                StickerRecordSchema.deserialize,
                allOffsets,
                StickerRecord(),
              ) ??
              [])
          as P;
    case 6:
      return (reader.readByteList(offset) ?? []) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _stickerPackGetId(StickerPack object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _stickerPackGetLinks(StickerPack object) {
  return [];
}

void _stickerPackAttach(
  IsarCollection<dynamic> col,
  Id id,
  StickerPack object,
) {
  object.id = id;
}

extension StickerPackByIndex on IsarCollection<StickerPack> {
  Future<StickerPack?> getByIdentifier(String identifier) {
    return getByIndex(r'identifier', [identifier]);
  }

  StickerPack? getByIdentifierSync(String identifier) {
    return getByIndexSync(r'identifier', [identifier]);
  }

  Future<bool> deleteByIdentifier(String identifier) {
    return deleteByIndex(r'identifier', [identifier]);
  }

  bool deleteByIdentifierSync(String identifier) {
    return deleteByIndexSync(r'identifier', [identifier]);
  }

  Future<List<StickerPack?>> getAllByIdentifier(List<String> identifierValues) {
    final values = identifierValues.map((e) => [e]).toList();
    return getAllByIndex(r'identifier', values);
  }

  List<StickerPack?> getAllByIdentifierSync(List<String> identifierValues) {
    final values = identifierValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'identifier', values);
  }

  Future<int> deleteAllByIdentifier(List<String> identifierValues) {
    final values = identifierValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'identifier', values);
  }

  int deleteAllByIdentifierSync(List<String> identifierValues) {
    final values = identifierValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'identifier', values);
  }

  Future<Id> putByIdentifier(StickerPack object) {
    return putByIndex(r'identifier', object);
  }

  Id putByIdentifierSync(StickerPack object, {bool saveLinks = true}) {
    return putByIndexSync(r'identifier', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByIdentifier(List<StickerPack> objects) {
    return putAllByIndex(r'identifier', objects);
  }

  List<Id> putAllByIdentifierSync(
    List<StickerPack> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'identifier', objects, saveLinks: saveLinks);
  }
}

extension StickerPackQueryWhereSort
    on QueryBuilder<StickerPack, StickerPack, QWhere> {
  QueryBuilder<StickerPack, StickerPack, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension StickerPackQueryWhere
    on QueryBuilder<StickerPack, StickerPack, QWhereClause> {
  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause> identifierEqualTo(
    String identifier,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'identifier', value: [identifier]),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterWhereClause>
  identifierNotEqualTo(String identifier) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'identifier',
                lower: [],
                upper: [identifier],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'identifier',
                lower: [identifier],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'identifier',
                lower: [identifier],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'identifier',
                lower: [],
                upper: [identifier],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension StickerPackQueryFilter
    on QueryBuilder<StickerPack, StickerPack, QFilterCondition> {
  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAtMillis', value: value),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAtMillis',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'identifier',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'identifier',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'identifier',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'identifier',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'identifier',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'identifier',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'identifier',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'identifier',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'identifier', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  identifierIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'identifier', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'publisher',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'publisher',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'publisher',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'publisher',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'publisher',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'publisher',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'publisher',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'publisher',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'publisher', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  publisherIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'publisher', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'stickerPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'stickerPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'stickerPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'stickerPaths',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'stickerPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'stickerPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'stickerPaths',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'stickerPaths',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'stickerPaths', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'stickerPaths', value: ''),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickerPaths', length, true, length, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickerPaths', 0, true, 0, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickerPaths', 0, false, 999999, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickerPaths', 0, true, length, include);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickerPaths', length, include, 999999, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickerPathsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stickerPaths',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickersLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickers', length, true, length, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickersIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickers', 0, true, 0, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickersIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickers', 0, false, 999999, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickersLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickers', 0, true, length, include);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickersLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'stickers', length, include, 999999, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  stickersLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'stickers',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trayIconBytes', value: value),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesElementGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trayIconBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesElementLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trayIconBytes',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trayIconBytes',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trayIconBytes', length, true, length, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trayIconBytes', 0, true, 0, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trayIconBytes', 0, false, 999999, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trayIconBytes', 0, true, length, include);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trayIconBytes', length, include, 999999, true);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  trayIconBytesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'trayIconBytes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  updatedAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAtMillis', value: value),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  updatedAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  updatedAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition>
  updatedAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAtMillis',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension StickerPackQueryObject
    on QueryBuilder<StickerPack, StickerPack, QFilterCondition> {
  QueryBuilder<StickerPack, StickerPack, QAfterFilterCondition> stickersElement(
    FilterQuery<StickerRecord> q,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'stickers');
    });
  }
}

extension StickerPackQueryLinks
    on QueryBuilder<StickerPack, StickerPack, QFilterCondition> {}

extension StickerPackQuerySortBy
    on QueryBuilder<StickerPack, StickerPack, QSortBy> {
  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy>
  sortByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByIdentifier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identifier', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByIdentifierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identifier', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByPublisher() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisher', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByPublisherDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisher', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> sortByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy>
  sortByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension StickerPackQuerySortThenBy
    on QueryBuilder<StickerPack, StickerPack, QSortThenBy> {
  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy>
  thenByCreatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtMillis', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByIdentifier() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identifier', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByIdentifierDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'identifier', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByPublisher() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisher', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByPublisherDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publisher', Sort.desc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy> thenByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.asc);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QAfterSortBy>
  thenByUpdatedAtMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtMillis', Sort.desc);
    });
  }
}

extension StickerPackQueryWhereDistinct
    on QueryBuilder<StickerPack, StickerPack, QDistinct> {
  QueryBuilder<StickerPack, StickerPack, QDistinct>
  distinctByCreatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtMillis');
    });
  }

  QueryBuilder<StickerPack, StickerPack, QDistinct> distinctByIdentifier({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'identifier', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QDistinct> distinctByPublisher({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publisher', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<StickerPack, StickerPack, QDistinct> distinctByStickerPaths() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stickerPaths');
    });
  }

  QueryBuilder<StickerPack, StickerPack, QDistinct> distinctByTrayIconBytes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trayIconBytes');
    });
  }

  QueryBuilder<StickerPack, StickerPack, QDistinct>
  distinctByUpdatedAtMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtMillis');
    });
  }
}

extension StickerPackQueryProperty
    on QueryBuilder<StickerPack, StickerPack, QQueryProperty> {
  QueryBuilder<StickerPack, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<StickerPack, int, QQueryOperations> createdAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtMillis');
    });
  }

  QueryBuilder<StickerPack, String, QQueryOperations> identifierProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'identifier');
    });
  }

  QueryBuilder<StickerPack, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<StickerPack, String, QQueryOperations> publisherProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publisher');
    });
  }

  QueryBuilder<StickerPack, List<String>, QQueryOperations>
  stickerPathsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stickerPaths');
    });
  }

  QueryBuilder<StickerPack, List<StickerRecord>, QQueryOperations>
  stickersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stickers');
    });
  }

  QueryBuilder<StickerPack, List<int>, QQueryOperations>
  trayIconBytesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trayIconBytes');
    });
  }

  QueryBuilder<StickerPack, int, QQueryOperations> updatedAtMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtMillis');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const StickerRecordSchema = Schema(
  name: r'StickerRecord',
  id: -5343070139297962764,
  properties: {
    r'accessibilityText': PropertySchema(
      id: 0,
      name: r'accessibilityText',
      type: IsarType.string,
    ),
    r'animated': PropertySchema(id: 1, name: r'animated', type: IsarType.bool),
    r'createdAtMillis': PropertySchema(
      id: 2,
      name: r'createdAtMillis',
      type: IsarType.long,
    ),
    r'filePath': PropertySchema(
      id: 3,
      name: r'filePath',
      type: IsarType.string,
    ),
    r'id': PropertySchema(id: 4, name: r'id', type: IsarType.string),
  },
  estimateSize: _stickerRecordEstimateSize,
  serialize: _stickerRecordSerialize,
  deserialize: _stickerRecordDeserialize,
  deserializeProp: _stickerRecordDeserializeProp,
);

int _stickerRecordEstimateSize(
  StickerRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.accessibilityText.length * 3;
  bytesCount += 3 + object.filePath.length * 3;
  bytesCount += 3 + object.id.length * 3;
  return bytesCount;
}

void _stickerRecordSerialize(
  StickerRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.accessibilityText);
  writer.writeBool(offsets[1], object.animated);
  writer.writeLong(offsets[2], object.createdAtMillis);
  writer.writeString(offsets[3], object.filePath);
  writer.writeString(offsets[4], object.id);
}

StickerRecord _stickerRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = StickerRecord();
  object.accessibilityText = reader.readString(offsets[0]);
  object.animated = reader.readBool(offsets[1]);
  object.createdAtMillis = reader.readLong(offsets[2]);
  object.filePath = reader.readString(offsets[3]);
  object.id = reader.readString(offsets[4]);
  return object;
}

P _stickerRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension StickerRecordQueryFilter
    on QueryBuilder<StickerRecord, StickerRecord, QFilterCondition> {
  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'accessibilityText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'accessibilityText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'accessibilityText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'accessibilityText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'accessibilityText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'accessibilityText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'accessibilityText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'accessibilityText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accessibilityText', value: ''),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  accessibilityTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'accessibilityText', value: ''),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  animatedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'animated', value: value),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  createdAtMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAtMillis', value: value),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  createdAtMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  createdAtMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAtMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  createdAtMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAtMillis',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'filePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'filePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'filePath', value: ''),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  filePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'filePath', value: ''),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  idStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition> idContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'id',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'id',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: ''),
      );
    });
  }

  QueryBuilder<StickerRecord, StickerRecord, QAfterFilterCondition>
  idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'id', value: ''),
      );
    });
  }
}

extension StickerRecordQueryObject
    on QueryBuilder<StickerRecord, StickerRecord, QFilterCondition> {}
