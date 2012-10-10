SELECT
  element_type,
  changeset_id,
  user_id,
  tstamp,
  tags,
  geom,
  u.name AS user_name
FROM
(
  SELECT
    'N' AS element_type,
    changeset_id,
    user_id,
    tstamp,
    tags,
    (SELECT ST_Union((g.gdump).geom) FROM (SELECT ST_DumpPoints(geom) AS gdump) AS g) AS geom
  FROM nodes
  WHERE changeset_id = #{changeset_id}

  UNION

  SELECT
    'R' AS element_type,
    changeset_id,
    user_id,
    tstamp,
    tags,
    NULL AS geom
  FROM relations
  WHERE changeset_id = #{changeset_id}

  UNION

  SELECT
    'W' AS element_type,
    changeset_id,
    user_id,
    tstamp,
    tags,
    (SELECT ST_Union((g.gdump).geom) FROM (SELECT ST_DumpPoints(linestring) AS gdump) AS g) AS geom
  FROM ways
  WHERE changeset_id = #{changeset_id}
) data
INNER JOIN users u ON (u.id = data.user_id)
