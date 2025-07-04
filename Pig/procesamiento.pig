
raw = LOAD '/data/incidentes.csv' USING PigStorage(',') AS (
    mongo_id:chararray,
    tipo:chararray,
    subtipo:chararray,
    comuna:chararray,
    timestamp:chararray,
    descripcion:chararray,
    id:chararray,
    x:float,
    y:float
);


datos = FILTER raw BY 
    tipo IS NOT NULL AND
    x IS NOT NULL AND
    y IS NOT NULL AND
    tipo != 'type' AND
    TRIM(tipo) != '' AND
    TRIM(id) != '';


datos_con_zona = FOREACH datos GENERATE
    id,
    LOWER(tipo) AS tipo,
    LOWER(subtipo) AS subtipo,
    LOWER(comuna) AS comuna,
    timestamp,
    descripcion,
    ROUND(x * 1000) AS x_zone,
    ROUND(y * 1000) AS y_zone;


grupo_zona = GROUP datos_con_zona BY (x_zone, y_zone);
eventos_por_zona = FOREACH grupo_zona {
    uno = LIMIT datos_con_zona 1;
    GENERATE
        FLATTEN(group) AS (x_zone, y_zone),
        FLATTEN(uno);
};


agrupadosTipo = GROUP eventos_por_zona BY tipo;
conteoTipo = FOREACH agrupadosTipo GENERATE group AS tipo, COUNT(eventos_por_zona);


agrupadosComuna = GROUP eventos_por_zona BY comuna;
conteoComuna = FOREACH agrupadosComuna GENERATE group AS comuna, COUNT(eventos_por_zona);


agrupadosAmbos = GROUP eventos_por_zona BY (tipo, comuna);
conteoAmbos = FOREACH agrupadosAmbos GENERATE
    group.tipo,
    group.comuna,
    COUNT(eventos_por_zona);


usuarios = FILTER raw BY 
    tipo IS NULL AND 
    id MATCHES 'user-.*' AND 
    x IS NOT NULL AND 
    y IS NOT NULL;

usuarios_zona = FOREACH usuarios GENERATE
    id AS user_id,
    ROUND(x * 1000) AS x_zone,
    ROUND(y * 1000) AS y_zone;


usuarios_zona_unicos = DISTINCT usuarios_zona;


agrupadosUsuarios = GROUP usuarios_zona_unicos BY (x_zone, y_zone);
conteoUsuarios = FOREACH agrupadosUsuarios {
    cantidad = COUNT(usuarios_zona_unicos);
    GENERATE
        group.x_zone AS x_zone,
        group.y_zone AS y_zone,
        cantidad AS cantidad;
};


conteoUsuarios_filtrado = FILTER conteoUsuarios BY cantidad > 1;

ordenadosTipo = ORDER conteoTipo BY $1 DESC;
topTipos = LIMIT ordenadosTipo 5;

ordenadosComuna = ORDER conteoComuna BY $1 DESC;
topComunas = LIMIT ordenadosComuna 5;

ordenadosUsuarios = ORDER conteoUsuarios_filtrado BY cantidad DESC;
zona_mas_concurrida = LIMIT ordenadosUsuarios 1;


STORE conteoTipo INTO '/data/output/tipo' USING PigStorage(',');
STORE conteoComuna INTO '/data/output/comuna' USING PigStorage(',');
STORE conteoAmbos INTO '/data/output/tipo_comuna' USING PigStorage(',');
STORE conteoUsuarios_filtrado INTO '/data/output/usuarios_por_zona' USING PigStorage(',');
STORE topTipos INTO '/data/output/top_tipos' USING PigStorage(',');
STORE topComunas INTO '/data/output/top_comunas' USING PigStorage(',');
STORE zona_mas_concurrida INTO '/data/output/zona_mas_concurrida' USING PigStorage(',');
