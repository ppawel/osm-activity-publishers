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
    geom
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
    linestring AS geom
  FROM ways
  WHERE changeset_id = #{changeset_id}
) data
INNER JOIN users u ON (u.id = data.user_id)
