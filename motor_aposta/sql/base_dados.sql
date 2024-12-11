create or replace function lista_dados (
   cd_tipo_jogo integer
) 
returns table ( "Concurso" Integer, "Data Sorteio" Date, "B1" Integer, "B2" Integer, "B3" Integer, "B4" Integer, "B5" Integer,
"B6" Integer, "B7" Integer, "B8" Integer, "B9" Integer, "B10" Integer, "B11" Integer, "B12" Integer, 
"B13" Integer, "B14" Integer, "B15" Integer, "Ganhou" Integer, "Ciclo" Integer, "Jogos" Integer, "Jogo" Integer, "Falta" Integer,
"F1" Integer, "F2" Integer, "F3" Integer, "F4" Integer, "F5" Integer, "F6" Integer, "F7" Integer, "F8" Integer, "F9" Integer, "F10" Integer ) 
language plpgsql
as $BODY$

begin

CREATE TEMP TABLE temp_tipo_jogo AS
SELECT *
  FROM tipo_jogo tp
 WHERE tp.id_tipo_jogo = cd_tipo_jogo;

CREATE TEMP TABLE temp_sorteio AS
SELECT * FROM crosstab(
  'select s.nr_concurso
	 , c.dt_concurso
	 , ROW_NUMBER () OVER ( PARTITION BY s.nr_concurso ORDER BY nr_sorteado ) as item
     , s.nr_sorteado
  from sorteio s
	   inner join temp_tipo_jogo tp on tp.id_tipo_jogo =s.id_tipo_jogo
	   inner join concurso c on c.nr_concurso = s.nr_concurso
	                        and c.id_tipo_jogo = s.id_tipo_jogo
 order by s.nr_concurso asc
        , s.nr_sorteado asc',
  'select m from generate_series(1,15) m'
) as ct(
  Concurso integer,
  "Data Sorteio" date,	
  "B1" integer,
  "B2" integer,
  "B3" integer,
  "B4" integer,
  "B5" integer,
  "B6" integer,
  "B7" integer,
  "B8" integer,
  "B9" integer,
  "B10" integer,
  "B11" integer,
  "B12" integer,
  "B13" integer,
  "B14" integer,
  "B15" integer
);

CREATE TEMP TABLE temp_ciclo AS
SELECT * FROM crosstab(
  'select cli.nr_concurso
	 , c.nr_ganhador
	 , CASE WHEN cl.bt_finalizado = 0
	        THEN 0
	        ELSE cl.id_ciclo
	   END as ciclo
	 , CASE WHEN cl.bt_finalizado = 0
	        THEN 0
	        ELSE DENSE_RANK() OVER ( PARTITION BY cl.id_ciclo, cl.id_tipo_jogo ORDER BY cl.nr_concurso )
	   END as Jogos
	 , DENSE_RANK() OVER ( PARTITION BY cl.id_ciclo, cl.id_tipo_jogo ORDER BY cl.nr_concurso ) as jogo
	 , tf.qt_falta
	 , ROW_NUMBER () OVER ( PARTITION BY cli.nr_concurso, cli.id_tipo_jogo, cli.id_ciclo ORDER BY cli.nr_ausente ) as item
     , cli.nr_ausente
  from ciclo_item cli
	   inner join temp_tipo_jogo tp on tp.id_tipo_jogo =cli.id_tipo_jogo
	   inner join concurso c on c.nr_concurso = cli.nr_concurso
	   inner join ciclo cl on cl.id_ciclo = cli.id_ciclo
	                      and cl.id_tipo_jogo = cli.id_tipo_jogo
	                      and cl.nr_concurso = cli.nr_concurso
	   inner join ( select t.id_ciclo
	                     , t.id_tipo_jogo
	                     , t.nr_concurso
	                     , COUNT(1) as qt_falta
	                  from ciclo_item t
	                 group by t.id_ciclo
	                        , t.id_tipo_jogo
	                        , t.nr_concurso
                  ) as tf on tf.id_ciclo = cli.id_ciclo
	                     and tf.id_tipo_jogo = cli.id_tipo_jogo
	                     and tf.nr_concurso = cli.nr_concurso
 order by cli.nr_concurso asc
        , cli.nr_ausente asc',
  'select m from generate_series(1,10) m'
) as ct(
  Concurso integer,
  Ganhou integer,
  Ciclo integer,
  Jogos integer,
  Jogo integer,
  Falta integer,
  "F1" integer,
  "F2" integer,
  "F3" integer,
  "F4" integer,
  "F5" integer,
  "F6" integer,
  "F7" integer,
  "F8" integer,
  "F9" integer,
  "F10" integer
);

RETURN QUERY (
SELECT s.Concurso
  , s."Data Sorteio"	
  , s."B1"
  , s."B2"
  , s."B3"
  , s."B4"
  , s."B5"
  , s."B6"
  , s."B7"
  , s."B8"
  , s."B9"
  , s."B10"
  , s."B11"
  , s."B12"
  , s."B13"
  , s."B14"
  , s."B15"
  , c.Ganhou 
  , c.Ciclo
  , c.Jogos 
  , c.Jogo 
  , c.Falta 
  , COALESCE(c."F1", 0) as F1
  , COALESCE(c."F2", 0) as F2
  , COALESCE(c."F3", 0) as F3
  , COALESCE(c."F4", 0) as F4
  , COALESCE(c."F5", 0) as F5
  , COALESCE(c."F6", 0) as F6
  , COALESCE(c."F7", 0) as F7
  , COALESCE(c."F8", 0) as F8
  , COALESCE(c."F9", 0) as F9
  , COALESCE(c."F10", 0) as F10
  FROM temp_sorteio s
       inner join temp_ciclo c on c.concurso = s.concurso 
 ORDER BY s.concurso
);

DROP TABLE IF EXISTS temp_tipo_jogo;
DROP TABLE IF EXISTS temp_sorteio;
DROP TABLE IF EXISTS temp_ciclo;

END;
$BODY$


