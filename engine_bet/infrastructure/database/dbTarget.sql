--
-- PostgreSQL database dump
--

-- Dumped from database version 15.3
-- Dumped by pg_dump version 15.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


--
-- Name: gera_ciclo(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.gera_ciclo(IN cd_tipo_jogo integer)
    LANGUAGE plpgsql
    AS $$
 

DECLARE 
     -- Declare a cursor
     sorteio_cursor CURSOR FOR SELECT c.nr_concurso 
	                             FROM concurso c 
								WHERE c.id_tipo_jogo = cd_tipo_jogo
								  AND NOT EXISTS ( SELECT 1
												     FROM ciclo cl
												    WHERE cl.nr_concurso = c.nr_concurso
												 )
								ORDER BY c.nr_concurso; 
     cd_concurso integer;
	 cd_concurso_anterior integer;
	 cd_ciclo integer;
	 bt_finalizado integer;
BEGIN

  -- Open the cursor 
  OPEN sorteio_cursor; 
     -- Loop through the cursor and process each row 
     LOOP 
       FETCH NEXT FROM sorteio_cursor INTO cd_concurso; 
       EXIT WHEN NOT FOUND; 
	   
	   cd_concurso_anterior := cd_concurso;
	   cd_ciclo := ( SELECT COALESCE(MAX(id_ciclo), 1) 
					   FROM ciclo cc
					  WHERE cc.id_tipo_jogo = cd_tipo_jogo
				   );
	   
	   SELECT COALESCE(cfl.bt_finalizado,0)
		 INTO bt_finalizado
		 FROM ciclo cfl
		WHERE cfl.id_ciclo = cd_ciclo
		  AND cfl.id_tipo_jogo = cd_tipo_jogo
		  ORDER BY cfl.nr_concurso DESC
		  LIMIT 1;
										
	   IF bt_finalizado = 1 THEN
	        --insere na finalização do ciclo
			cd_ciclo := cd_ciclo + 1;
			bt_finalizado := 0;			
	   END IF;
	   
	   INSERT INTO ciclo (id_ciclo, id_tipo_jogo, nr_concurso, bt_finalizado) 
			      VALUES (cd_ciclo, cd_tipo_jogo, cd_concurso, 0);
				  
	   CREATE TEMP TABLE temp_historico_sorteio AS
	      SELECT DISTINCT
		         s1.nr_sorteado
			FROM sorteio s1
           WHERE s1.nr_concurso = cd_concurso
             AND s1.id_tipo_jogo = cd_tipo_jogo
           UNION
          SELECT DISTINCT 
		         s2.nr_sorteado
            FROM sorteio s2
			     INNER JOIN ciclo_item c_item ON c_item.nr_concurso = s2.nr_concurso
				                             AND c_item.id_tipo_jogo = s2.id_tipo_jogo
           WHERE c_item.id_ciclo = cd_ciclo
		     AND c_item.id_tipo_jogo = cd_tipo_jogo;
             
	   CREATE TEMP TABLE temp_ciclo_item AS
	          SELECT DISTINCT 
                     e.nr_estrutura_jogo AS nr_ausente
                FROM tipo_jogo_estrutura e
               WHERE e.id_tipo_jogo = cd_tipo_jogo
		         AND NOT EXISTS ( SELECT 1
			  	                    FROM temp_historico_sorteio s 
				                   WHERE s.nr_sorteado = e.nr_estrutura_jogo
                  	            );
								
	   DROP TABLE temp_historico_sorteio;
	   		   
	   IF NOT EXISTS (SELECT 1 FROM temp_ciclo_item) THEN
	       INSERT INTO ciclo_item (id_ciclo, id_tipo_jogo, nr_concurso, nr_ausente)
	         SELECT cd_ciclo
		          , cd_tipo_jogo
			      , cd_concurso
		          , 0;
				  
	       UPDATE ciclo c_update
		      SET bt_finalizado = 1
			WHERE c_update.nr_concurso = cd_concurso
			  AND c_update.id_tipo_jogo = cd_tipo_jogo
			  AND c_update.id_ciclo = cd_ciclo;
	   ELSE
	       INSERT INTO ciclo_item (id_ciclo, id_tipo_jogo, nr_concurso, nr_ausente)
	         SELECT cd_ciclo
		          , cd_tipo_jogo
			      , cd_concurso
		          , c_item.nr_ausente
		       FROM temp_ciclo_item c_item;
	   END IF;
	   
       DROP TABLE temp_ciclo_item;
     END LOOP; 
  -- Close the cursor 
  CLOSE sorteio_cursor;
END; 
$$;


ALTER PROCEDURE public.gera_ciclo(IN cd_tipo_jogo integer) OWNER TO postgres;

--
-- Name: lista_dados(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lista_dados(cd_tipo_jogo integer) RETURNS TABLE("Concurso" integer, "Data Sorteio" date, "B1" integer, "B2" integer, "B3" integer, "B4" integer, "B5" integer, "B6" integer, "B7" integer, "B8" integer, "B9" integer, "B10" integer, "B11" integer, "B12" integer, "B13" integer, "B14" integer, "B15" integer, "Ganhou" integer, "Ciclo" integer, "Jogos" integer, "Jogo" integer, "Falta" integer, "F1" integer, "F2" integer, "F3" integer, "F4" integer, "F5" integer, "F6" integer, "F7" integer, "F8" integer, "F9" integer, "F10" integer)
    LANGUAGE plpgsql
    AS $$

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
$$;


ALTER FUNCTION public.lista_dados(cd_tipo_jogo integer) OWNER TO postgres;

--
-- Name: process_sorteio(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.process_sorteio() RETURNS TABLE(nr_concurso integer, id_tipo_jogo integer)
    LANGUAGE plpgsql
    AS $$ 
DECLARE 
     -- Declare a cursor
     sorteio_cursor CURSOR FOR SELECT c.nr_concurso 
	                             FROM concurso c 
								WHERE NOT EXISTS ( SELECT 1
												     FROM ciclo cl
												    WHERE cl.nr_concurso = c.nr_concurso
												 ); 
     cd_concurso integer;
	 cd_concurso_anterior integer;
	 cd_ciclo integer;
BEGIN 
  -- Open the cursor 
  OPEN sorteio_cursor; 
     -- Loop through the cursor and process each row 
     LOOP 
       FETCH NEXT FROM sorteio_cursor INTO cd_concurso; 
       EXIT WHEN NOT FOUND; 
	   cd_concurso_anterior := cd_concurso;
	   SELECT cd_ciclo=COALESCE(MAX(id_ciclo),0)
	     FROM ciclo;
		 
	   RETURN QUERY (select distinct
					        cd_concurso as nr_concurso
                          , e.nr_estrutura_jogo
                        from tipo_jogo_estrutura e
                       where not exists ( select 1
				                            from sorteio s 
				                           where s.nr_concurso = cd_concurso
				                             and s.id_tipo_jogo = e.id_tipo_jogo
				                             and s.nr_sorteado = e.nr_estrutura_jogo
                  				        )
					     and not exists ( select 1
										    from ciclo_item cli
										   where cli.id_ciclo = cd_ciclo
										     and cli.nr_ausente = e.nr_estrutura_jogo
										)
					);
     END LOOP; 
  -- Close the cursor 
  CLOSE sorteio_cursor; 
END; 
$$;


ALTER FUNCTION public.process_sorteio() OWNER TO postgres;

--
-- Name: process_sorteio(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.process_sorteio(cd_tipo_jogo integer) RETURNS TABLE(nr_concurso integer, id_tipo_jogo integer)
    LANGUAGE plpgsql
    AS $$ 

DECLARE 
     -- Declare a cursor
     sorteio_cursor CURSOR FOR SELECT c.nr_concurso 
	                             FROM concurso c 
								WHERE c.id_tipo_jogo = cd_tipo_jogo
								  AND NOT EXISTS ( SELECT 1
												     FROM ciclo cl
												    WHERE cl.nr_concurso = c.nr_concurso
												 )
								ORDER BY c.nr_concurso; 
     cd_concurso integer;
	 cd_concurso_anterior integer;
	 cd_ciclo integer;
	 bt_finalizado integer;
BEGIN

  -- Open the cursor 
  OPEN sorteio_cursor; 
     -- Loop through the cursor and process each row 
     LOOP 
       FETCH NEXT FROM sorteio_cursor INTO cd_concurso; 
       EXIT WHEN NOT FOUND; 
	   
	   cd_concurso_anterior := cd_concurso;
	   cd_ciclo := ( SELECT COALESCE(MAX(id_ciclo), 0) 
					   FROM ciclo cc
					  WHERE cc.id_tipo_jogo = cd_tipo_jogo
				   );
	   
	   SELECT COALESCE(cfl.bt_finalizado,0)
		 INTO bt_finalizado
		 FROM ciclo cfl
		WHERE cfl.id_ciclo = cd_ciclo
		  AND cfl.id_tipo_jogo = cd_tipo_jogo
		  ORDER BY cfl.nr_concurso DESC
		  LIMIT 1;
						
						
	   return query(select 0 as nr_concurso, bt_finalizado as id_tipo_jogo);					
	   IF bt_finalizado = 1 THEN
	        --insere na finalização do ciclo
			cd_ciclo := cd_ciclo + 1;
			bt_finalizado := 0;
            return query(select 7 as nr_concurso, 7 as id_tipo_jogo);			
	   END IF;
	   
	   INSERT INTO ciclo (id_ciclo, id_tipo_jogo, nr_concurso, bt_finalizado) 
			      VALUES (cd_ciclo, cd_tipo_jogo, cd_concurso, 0);
				  
	   CREATE TEMP TABLE temp_historico_sorteio AS
	      SELECT DISTINCT
		         s1.nr_sorteado
			FROM sorteio s1
           WHERE s1.nr_concurso = cd_concurso
             AND s1.id_tipo_jogo = cd_tipo_jogo
           UNION
          SELECT DISTINCT 
		         s2.nr_sorteado
            FROM sorteio s2
			     INNER JOIN ciclo_item c_item ON c_item.nr_concurso = s2.nr_concurso
				                             AND c_item.id_tipo_jogo = s2.id_tipo_jogo
           WHERE c_item.id_ciclo = cd_ciclo
		     AND c_item.id_tipo_jogo = cd_tipo_jogo;
             
	   CREATE TEMP TABLE temp_ciclo_item AS
	          SELECT DISTINCT 
                     e.nr_estrutura_jogo AS nr_ausente
                FROM tipo_jogo_estrutura e
               WHERE e.id_tipo_jogo = cd_tipo_jogo
		         AND NOT EXISTS ( SELECT 1
			  	                    FROM temp_historico_sorteio s 
				                   WHERE s.nr_sorteado = e.nr_estrutura_jogo
                  	            );
								
	   DROP TABLE temp_historico_sorteio;
	   		   
	   IF NOT EXISTS (SELECT 1 FROM temp_ciclo_item) THEN
	       INSERT INTO ciclo_item (id_ciclo, id_tipo_jogo, nr_concurso, nr_ausente)
	         SELECT cd_ciclo
		          , cd_tipo_jogo
			      , cd_concurso
		          , 0;
				  
	       UPDATE ciclo c_update
		      SET bt_finalizado = 1
			WHERE c_update.nr_concurso = cd_concurso
			  AND c_update.id_tipo_jogo = cd_tipo_jogo
			  AND c_update.id_ciclo = cd_ciclo;
	   ELSE
	       INSERT INTO ciclo_item (id_ciclo, id_tipo_jogo, nr_concurso, nr_ausente)
	         SELECT cd_ciclo
		          , cd_tipo_jogo
			      , cd_concurso
		          , c_item.nr_ausente
		       FROM temp_ciclo_item c_item;
	   END IF;
	   
       DROP TABLE temp_ciclo_item;
     END LOOP; 
  -- Close the cursor 
  CLOSE sorteio_cursor;
  
  return query(select 1 as nr_concurso, 2 as id_tipo_jogo);
END; 
$$;


ALTER FUNCTION public.process_sorteio(cd_tipo_jogo integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aposta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aposta (
    id_aposta integer NOT NULL,
    id_usuario integer NOT NULL,
    id_tipo_jogo integer NOT NULL,
    nr_concurso integer,
    dt_aposta date DEFAULT CURRENT_DATE NOT NULL
);


ALTER TABLE public.aposta OWNER TO postgres;

--
-- Name: aposta_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aposta_item (
    id_aposta integer NOT NULL,
    id_usuario integer NOT NULL,
    id_tipo_jogo integer NOT NULL,
    nr_aposta integer NOT NULL
);


ALTER TABLE public.aposta_item OWNER TO postgres;

--
-- Name: ciclo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ciclo (
    id_ciclo integer NOT NULL,
    id_tipo_jogo integer NOT NULL,
    nr_concurso integer NOT NULL,
    bt_finalizado integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.ciclo OWNER TO postgres;

--
-- Name: ciclo_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ciclo_item (
    id_ciclo integer NOT NULL,
    id_tipo_jogo integer NOT NULL,
    nr_concurso integer NOT NULL,
    nr_ausente integer NOT NULL
);


ALTER TABLE public.ciclo_item OWNER TO postgres;

--
-- Name: concurso; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.concurso (
    id_tipo_jogo integer NOT NULL,
    nr_concurso integer NOT NULL,
    dt_concurso date,
    vl_acumulado numeric(18,2),
    nr_proximo_concurso integer,
    dt_proximo_concurso date,
    nr_ganhador integer
);


ALTER TABLE public.concurso OWNER TO postgres;

--
-- Name: parametro; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parametro (
    id_parametro integer NOT NULL,
    nm_base_url_atualizacao character varying(50) NOT NULL
);


ALTER TABLE public.parametro OWNER TO postgres;

--
-- Name: sorteio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sorteio (
    id_tipo_jogo integer NOT NULL,
    nr_concurso integer NOT NULL,
    nr_sorteado integer NOT NULL
);


ALTER TABLE public.sorteio OWNER TO postgres;

--
-- Name: tipo_jogo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_jogo (
    id_tipo_jogo integer NOT NULL,
    nm_tipo_jogo character varying(50) NOT NULL,
    qt_dezena_resultado smallint NOT NULL,
    qt_dezena_minima_aposta smallint NOT NULL,
    qt_dezena_maxima_apota smallint NOT NULL,
    nm_route character varying(50)
);


ALTER TABLE public.tipo_jogo OWNER TO postgres;

--
-- Name: tipo_jogo_estrutura; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_jogo_estrutura (
    id_tipo_jogo integer NOT NULL,
    nr_estrutura_jogo integer NOT NULL
);


ALTER TABLE public.tipo_jogo_estrutura OWNER TO postgres;

--
-- Name: tipo_jogo_premiacao; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_jogo_premiacao (
    id_tipo_jogo integer NOT NULL,
    seq_tipo_jogo smallint NOT NULL,
    qt_dezena_acerto smallint NOT NULL,
    vl_premio numeric(18,2),
    ind_valor_variavel bit(1) NOT NULL
);


ALTER TABLE public.tipo_jogo_premiacao OWNER TO postgres;

--
-- Name: usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario (
    id_usuario integer NOT NULL,
    nm_usuario character varying(100) NOT NULL,
    ds_email character varying(200) NOT NULL,
    ds_hashsenha text NOT NULL,
    dt_nascimento date NOT NULL,
    dt_cadastro date DEFAULT CURRENT_DATE NOT NULL,
    ds_numero_celular character varying(20)
);


ALTER TABLE public.usuario OWNER TO postgres;

--
-- Name: vw_sorteio; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_sorteio AS
 SELECT sorteio.nr_concurso,
    string_agg(((sorteio.nr_sorteado)::character varying(50))::text, ','::text) AS string_agg
   FROM public.sorteio
  GROUP BY sorteio.nr_concurso;


ALTER TABLE public.vw_sorteio OWNER TO postgres;

--
-- Data for Name: aposta; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.aposta (id_aposta, id_usuario, id_tipo_jogo, nr_concurso, dt_aposta) FROM stdin;
1	1	1	3012	2024-01-24
\.


--
-- Data for Name: aposta_item; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.aposta_item (id_aposta, id_usuario, id_tipo_jogo, nr_aposta) FROM stdin;
1	1	1	1
1	1	1	3
1	1	1	4
1	1	1	6
1	1	1	7
1	1	1	11
1	1	1	14
1	1	1	15
1	1	1	16
1	1	1	25
1	1	1	17
1	1	1	18
1	1	1	21
1	1	1	23
1	1	1	24
\.


--
-- Data for Name: ciclo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ciclo (id_ciclo, id_tipo_jogo, nr_concurso, bt_finalizado) FROM stdin;
152	1	736	0
152	1	737	0
152	1	738	0
152	1	739	0
152	1	740	1
153	1	741	0
153	1	742	0
153	1	743	0
153	1	744	1
154	1	745	0
154	1	746	0
154	1	747	0
154	1	748	0
154	1	749	1
155	1	750	0
155	1	751	0
155	1	752	1
156	1	753	0
156	1	754	0
156	1	755	0
156	1	756	0
156	1	757	1
157	1	758	0
157	1	759	0
157	1	760	0
157	1	761	0
157	1	762	1
158	1	763	0
158	1	764	0
158	1	765	0
158	1	766	1
159	1	767	0
159	1	768	0
159	1	769	0
159	1	770	0
159	1	771	1
160	1	772	0
160	1	773	0
160	1	774	0
160	1	775	0
160	1	776	0
160	1	777	1
161	1	778	0
161	1	779	0
161	1	780	0
161	1	781	1
162	1	782	0
162	1	783	0
162	1	784	1
163	1	785	0
163	1	786	0
163	1	787	0
163	1	788	0
163	1	789	1
164	1	790	0
164	1	791	0
164	1	792	0
164	1	793	0
164	1	794	1
165	1	795	0
165	1	796	0
165	1	797	0
165	1	798	1
166	1	799	0
166	1	800	0
166	1	801	0
166	1	802	0
166	1	803	0
166	1	804	0
166	1	805	1
167	1	806	0
167	1	807	0
167	1	808	0
167	1	809	1
168	1	810	0
168	1	811	0
168	1	812	0
168	1	813	0
168	1	814	1
169	1	815	0
169	1	816	0
169	1	817	1
170	1	818	0
170	1	819	0
170	1	820	0
170	1	821	1
171	1	822	0
171	1	823	0
171	1	824	0
171	1	825	1
172	1	826	0
172	1	827	0
172	1	828	0
172	1	829	1
173	1	830	0
173	1	831	0
173	1	832	1
174	1	833	0
174	1	834	0
174	1	835	0
174	1	836	0
174	1	837	1
175	1	838	0
175	1	839	0
175	1	840	0
175	1	841	1
176	1	842	0
176	1	843	0
176	1	844	0
176	1	845	1
177	1	846	0
177	1	847	0
177	1	848	0
177	1	849	0
177	1	850	1
178	1	851	0
178	1	852	0
178	1	853	1
179	1	854	0
179	1	855	0
179	1	856	0
179	1	857	1
180	1	858	0
180	1	859	0
180	1	860	0
180	1	861	0
180	1	862	0
180	1	863	0
180	1	864	1
181	1	865	0
181	1	866	0
181	1	867	0
181	1	868	1
182	1	869	0
182	1	870	0
182	1	871	1
183	1	872	0
183	1	873	0
183	1	874	0
183	1	875	1
184	1	876	0
184	1	877	0
184	1	878	0
184	1	879	0
184	1	880	0
184	1	881	0
184	1	882	1
185	1	883	0
185	1	884	0
185	1	885	0
185	1	886	0
185	1	887	0
650	1	3055	0
650	1	3057	0
653	1	3070	0
657	1	3090	0
661	1	3105	0
663	1	3115	0
185	1	888	1
186	1	889	0
186	1	890	0
186	1	891	0
186	1	892	1
187	1	893	0
187	1	894	0
187	1	895	0
187	1	896	0
187	1	897	1
188	1	898	0
188	1	899	0
188	1	900	0
188	1	901	0
188	1	902	0
188	1	903	0
188	1	904	1
189	1	905	0
189	1	906	0
189	1	907	0
189	1	908	0
189	1	909	0
189	1	910	1
190	1	911	0
190	1	912	0
190	1	913	0
190	1	914	0
190	1	915	0
190	1	916	0
190	1	917	0
190	1	918	1
191	1	919	0
191	1	920	0
191	1	921	0
191	1	922	1
192	1	923	0
192	1	924	0
192	1	925	0
192	1	926	1
193	1	927	0
193	1	928	0
193	1	929	1
194	1	930	0
194	1	931	0
194	1	932	0
194	1	933	1
195	1	934	0
195	1	935	0
195	1	936	0
195	1	937	1
196	1	938	0
196	1	939	0
196	1	940	0
196	1	941	0
196	1	942	1
197	1	943	0
197	1	944	0
197	1	945	0
197	1	946	1
198	1	947	0
198	1	948	0
198	1	949	0
198	1	950	1
199	1	951	0
199	1	952	0
199	1	953	1
200	1	954	0
200	1	955	0
200	1	956	0
200	1	957	1
201	1	958	0
201	1	959	0
201	1	960	0
201	1	961	0
201	1	962	1
202	1	963	0
202	1	964	0
202	1	965	0
202	1	966	1
203	1	967	0
203	1	968	0
203	1	969	0
203	1	970	1
204	1	971	0
204	1	972	0
204	1	973	0
204	1	974	1
205	1	975	0
205	1	976	0
205	1	977	0
205	1	978	1
206	1	979	0
206	1	980	0
206	1	981	0
206	1	982	0
206	1	983	1
207	1	984	0
207	1	985	0
207	1	986	0
207	1	987	1
208	1	988	0
208	1	989	0
208	1	990	0
208	1	991	1
209	1	992	0
209	1	993	0
209	1	994	0
209	1	995	0
209	1	996	1
210	1	997	0
210	1	998	0
210	1	999	0
210	1	1000	0
593	1	2795	1
594	1	2796	0
594	1	2797	0
594	1	2798	0
594	1	2799	0
594	1	2800	1
595	1	2801	0
595	1	2802	0
595	1	2803	0
595	1	2804	1
596	1	2805	0
596	1	2806	0
596	1	2807	0
596	1	2808	1
597	1	2809	0
597	1	2810	0
597	1	2811	0
597	1	2812	0
597	1	2813	0
597	1	2814	0
597	1	2815	0
597	1	2816	0
597	1	2817	1
598	1	2818	0
598	1	2819	0
598	1	2820	0
598	1	2821	0
598	1	2822	0
598	1	2823	1
599	1	2824	0
599	1	2825	0
599	1	2826	0
599	1	2827	1
600	1	2828	0
600	1	2829	0
600	1	2830	0
600	1	2831	0
600	1	2832	1
601	1	2833	0
601	1	2834	0
601	1	2835	1
602	1	2836	0
602	1	2837	0
602	1	2838	1
603	1	2839	0
603	1	2840	0
603	1	2841	1
604	1	2842	0
604	1	2843	0
604	1	2844	0
604	1	2845	1
605	1	2846	0
605	1	2847	0
605	1	2848	0
605	1	2849	0
605	1	2850	0
605	1	2851	1
650	1	3058	0
653	1	3071	0
657	1	3091	0
661	1	3106	0
663	1	3116	0
210	1	1001	1
211	1	1002	0
211	1	1003	0
211	1	1004	0
211	1	1005	0
211	1	1006	0
211	1	1007	1
212	1	1008	0
212	1	1009	0
212	1	1010	0
212	1	1011	1
213	1	1012	0
213	1	1013	0
213	1	1014	0
213	1	1015	1
214	1	1016	0
214	1	1017	0
214	1	1018	0
214	1	1019	0
214	1	1020	1
215	1	1021	0
215	1	1022	0
215	1	1023	0
215	1	1024	1
216	1	1025	0
216	1	1026	0
216	1	1027	0
216	1	1028	1
217	1	1029	0
217	1	1030	0
217	1	1031	0
217	1	1032	0
217	1	1033	1
218	1	1034	0
218	1	1035	0
218	1	1036	0
218	1	1037	0
218	1	1038	1
219	1	1039	0
219	1	1040	0
219	1	1041	0
219	1	1042	1
220	1	1043	0
220	1	1044	0
220	1	1045	0
220	1	1046	1
221	1	1047	0
221	1	1048	0
221	1	1049	0
221	1	1050	1
222	1	1051	0
222	1	1052	0
222	1	1053	0
222	1	1054	0
222	1	1055	0
222	1	1056	1
223	1	1057	0
223	1	1058	0
223	1	1059	0
223	1	1060	0
223	1	1061	0
223	1	1062	0
223	1	1063	1
224	1	1064	0
224	1	1065	0
224	1	1066	0
224	1	1067	1
225	1	1068	0
225	1	1069	0
225	1	1070	0
225	1	1071	1
226	1	1072	0
226	1	1073	0
226	1	1074	0
226	1	1075	1
227	1	1076	0
227	1	1077	0
227	1	1078	0
227	1	1079	0
227	1	1080	1
228	1	1081	0
228	1	1082	0
228	1	1083	0
228	1	1084	0
228	1	1085	1
229	1	1086	0
229	1	1087	0
229	1	1088	0
229	1	1089	0
229	1	1090	0
229	1	1091	1
230	1	1092	0
230	1	1093	0
230	1	1094	0
230	1	1095	1
231	1	1096	0
231	1	1097	0
231	1	1098	0
231	1	1099	0
231	1	1100	0
231	1	1101	1
232	1	1102	0
232	1	1103	0
232	1	1104	0
232	1	1105	1
233	1	1106	0
233	1	1107	0
233	1	1108	0
233	1	1109	1
234	1	1110	0
234	1	1111	0
234	1	1112	0
234	1	1113	0
234	1	1114	0
234	1	1115	0
234	1	1116	1
235	1	1117	0
235	1	1118	0
235	1	1119	0
235	1	1120	0
235	1	1121	1
236	1	1122	0
236	1	1123	0
236	1	1124	0
236	1	1125	1
237	1	1126	0
237	1	1127	0
237	1	1128	0
237	1	1129	1
238	1	1130	0
238	1	1131	0
238	1	1132	0
238	1	1133	1
239	1	1134	0
239	1	1135	0
239	1	1136	1
240	1	1137	0
240	1	1138	0
240	1	1139	0
240	1	1140	1
241	1	1141	0
241	1	1142	0
241	1	1143	0
241	1	1144	0
241	1	1145	0
241	1	1146	1
242	1	1147	0
242	1	1148	0
242	1	1149	1
243	1	1150	0
243	1	1151	0
243	1	1152	0
650	1	3056	0
650	1	3059	0
653	1	3072	0
657	1	3092	0
661	1	3107	0
663	1	3117	1
243	1	1153	1
244	1	1154	0
244	1	1155	0
244	1	1156	0
244	1	1157	0
244	1	1158	1
245	1	1159	0
245	1	1160	0
245	1	1161	0
245	1	1162	0
245	1	1163	1
246	1	1164	0
246	1	1165	0
246	1	1166	0
246	1	1167	1
247	1	1168	0
247	1	1169	0
247	1	1170	0
247	1	1171	0
247	1	1172	1
248	1	1173	0
248	1	1174	0
248	1	1175	1
249	1	1176	0
249	1	1177	0
249	1	1178	0
249	1	1179	0
249	1	1180	1
250	1	1181	0
250	1	1182	0
250	1	1183	0
250	1	1184	1
251	1	1185	0
251	1	1186	0
251	1	1187	0
251	1	1188	0
251	1	1189	1
252	1	1190	0
252	1	1191	0
252	1	1192	0
252	1	1193	1
253	1	1194	0
253	1	1195	0
253	1	1196	0
253	1	1197	0
253	1	1198	1
254	1	1199	0
254	1	1200	0
254	1	1201	0
254	1	1202	1
255	1	1203	0
255	1	1204	0
255	1	1205	0
255	1	1206	0
255	1	1207	1
256	1	1208	0
256	1	1209	0
256	1	1210	0
256	1	1211	0
256	1	1212	1
257	1	1213	0
257	1	1214	0
257	1	1215	1
258	1	1216	0
258	1	1217	0
258	1	1218	0
258	1	1219	1
259	1	1220	0
259	1	1221	0
259	1	1222	0
259	1	1223	1
260	1	1224	0
260	1	1225	0
260	1	1226	1
261	1	1227	0
261	1	1228	0
261	1	1229	0
261	1	1230	0
261	1	1231	1
262	1	1232	0
262	1	1233	0
262	1	1234	0
262	1	1235	0
262	1	1236	1
263	1	1237	0
263	1	1238	0
263	1	1239	0
263	1	1240	0
263	1	1241	0
263	1	1242	1
264	1	1243	0
264	1	1244	0
264	1	1245	0
264	1	1246	0
264	1	1247	1
265	1	1248	0
265	1	1249	0
265	1	1250	0
265	1	1251	1
266	1	1252	0
266	1	1253	0
266	1	1254	0
266	1	1255	0
266	1	1256	1
267	1	1257	0
267	1	1258	0
267	1	1259	0
267	1	1260	1
268	1	1261	0
268	1	1262	0
268	1	1263	0
268	1	1264	0
268	1	1265	1
269	1	1266	0
269	1	1267	0
269	1	1268	0
269	1	1269	0
269	1	1270	0
269	1	1271	0
269	1	1272	1
270	1	1273	0
270	1	1274	0
270	1	1275	0
270	1	1276	0
270	1	1277	1
271	1	1278	0
271	1	1279	0
271	1	1280	0
271	1	1281	0
271	1	1282	0
271	1	1283	1
272	1	1284	0
272	1	1285	0
272	1	1286	0
272	1	1287	0
272	1	1288	0
272	1	1289	0
272	1	1290	1
273	1	1291	0
273	1	1292	0
273	1	1293	0
273	1	1294	0
273	1	1295	0
273	1	1296	0
273	1	1297	0
273	1	1298	1
274	1	1299	0
274	1	1300	0
274	1	1301	1
275	1	1302	0
275	1	1303	0
275	1	1304	0
275	1	1305	0
650	1	3060	0
653	1	3073	0
657	1	3093	1
661	1	3108	1
664	1	3118	0
275	1	1306	0
275	1	1307	0
275	1	1308	0
275	1	1309	1
276	1	1310	0
276	1	1311	0
276	1	1312	0
276	1	1313	1
277	1	1314	0
277	1	1315	0
277	1	1316	0
277	1	1317	0
277	1	1318	1
278	1	1319	0
278	1	1320	0
278	1	1321	0
278	1	1322	1
279	1	1323	0
279	1	1324	0
279	1	1325	0
279	1	1326	0
279	1	1327	0
279	1	1328	0
279	1	1329	0
279	1	1330	1
280	1	1331	0
280	1	1332	0
280	1	1333	0
280	1	1334	1
281	1	1335	0
281	1	1336	0
281	1	1337	0
281	1	1338	1
282	1	1339	0
282	1	1340	0
282	1	1341	0
282	1	1342	1
283	1	1343	0
283	1	1344	0
283	1	1345	0
283	1	1346	1
284	1	1347	0
284	1	1348	0
284	1	1349	0
284	1	1350	1
285	1	1351	0
285	1	1352	0
285	1	1353	0
285	1	1354	1
286	1	1355	0
286	1	1356	0
286	1	1357	0
286	1	1358	0
286	1	1359	0
286	1	1360	0
286	1	1361	1
287	1	1362	0
287	1	1363	0
287	1	1364	0
287	1	1365	0
287	1	1366	1
288	1	1367	0
288	1	1368	0
288	1	1369	0
288	1	1370	0
288	1	1371	0
288	1	1372	1
289	1	1373	0
289	1	1374	0
289	1	1375	0
289	1	1376	1
290	1	1377	0
290	1	1378	0
290	1	1379	0
290	1	1380	1
291	1	1381	0
291	1	1382	0
291	1	1383	0
291	1	1384	0
291	1	1385	1
292	1	1386	0
292	1	1387	0
292	1	1388	1
293	1	1389	0
293	1	1390	0
293	1	1391	0
293	1	1392	1
294	1	1393	0
294	1	1394	0
294	1	1395	0
294	1	1396	0
294	1	1397	0
294	1	1398	0
294	1	1399	0
294	1	1400	1
295	1	1401	0
295	1	1402	0
295	1	1403	1
296	1	1404	0
296	1	1405	0
296	1	1406	0
296	1	1407	0
296	1	1408	0
296	1	1409	1
297	1	1410	0
297	1	1411	0
297	1	1412	1
298	1	1413	0
298	1	1414	0
298	1	1415	0
298	1	1416	0
298	1	1417	1
299	1	1418	0
299	1	1419	0
299	1	1420	0
299	1	1421	1
300	1	1422	0
300	1	1423	0
300	1	1424	0
300	1	1425	1
301	1	1426	0
301	1	1427	0
301	1	1428	1
302	1	1429	0
302	1	1430	0
302	1	1431	0
302	1	1432	0
302	1	1433	1
303	1	1434	0
303	1	1435	0
303	1	1436	0
303	1	1437	1
304	1	1438	0
304	1	1439	0
304	1	1440	0
304	1	1441	1
305	1	1442	0
305	1	1443	0
305	1	1444	0
305	1	1445	1
306	1	1446	0
306	1	1447	0
306	1	1448	0
306	1	1449	0
306	1	1450	1
307	1	1451	0
307	1	1452	0
307	1	1453	0
307	1	1454	0
307	1	1455	0
307	1	1456	1
308	1	1457	0
650	1	3061	0
653	1	3074	0
658	1	3094	0
662	1	3109	0
664	1	3119	0
308	1	1458	0
308	1	1459	0
308	1	1460	1
309	1	1461	0
309	1	1462	0
309	1	1463	0
309	1	1464	0
309	1	1465	1
310	1	1466	0
310	1	1467	0
310	1	1468	0
310	1	1469	0
310	1	1470	1
311	1	1471	0
311	1	1472	0
311	1	1473	0
311	1	1474	0
311	1	1475	0
311	1	1476	0
311	1	1477	1
312	1	1478	0
312	1	1479	0
312	1	1480	0
312	1	1481	0
312	1	1482	1
313	1	1483	0
313	1	1484	0
313	1	1485	0
313	1	1486	0
313	1	1487	1
314	1	1488	0
314	1	1489	0
314	1	1490	0
314	1	1491	0
314	1	1492	1
315	1	1493	0
315	1	1494	0
315	1	1495	0
315	1	1496	1
316	1	1497	0
316	1	1498	0
316	1	1499	0
316	1	1500	0
316	1	1501	1
317	1	1502	0
317	1	1503	0
317	1	1504	0
317	1	1505	0
317	1	1506	1
318	1	1507	0
318	1	1508	0
318	1	1509	0
318	1	1510	0
318	1	1511	0
318	1	1512	0
318	1	1513	0
318	1	1514	0
318	1	1515	0
318	1	1516	0
318	1	1517	1
319	1	1518	0
319	1	1519	0
319	1	1520	0
319	1	1521	1
320	1	1522	0
320	1	1523	0
320	1	1524	0
320	1	1525	0
320	1	1526	1
321	1	1527	0
321	1	1528	0
321	1	1529	0
321	1	1530	1
322	1	1531	0
322	1	1532	0
322	1	1533	0
322	1	1534	1
323	1	1535	0
323	1	1536	0
323	1	1537	0
323	1	1538	0
323	1	1539	1
324	1	1540	0
324	1	1541	0
324	1	1542	0
324	1	1543	1
325	1	1544	0
325	1	1545	0
325	1	1546	0
325	1	1547	1
326	1	1548	0
326	1	1549	0
326	1	1550	0
326	1	1551	0
326	1	1552	0
326	1	1553	0
326	1	1554	0
326	1	1555	1
327	1	1556	0
327	1	1557	0
327	1	1558	0
327	1	1559	0
327	1	1560	0
327	1	1561	1
328	1	1562	0
328	1	1563	0
328	1	1564	0
328	1	1565	1
329	1	1566	0
329	1	1567	0
329	1	1568	0
329	1	1569	1
330	1	1570	0
330	1	1571	0
330	1	1572	0
330	1	1573	1
331	1	1574	0
331	1	1575	0
331	1	1576	0
331	1	1577	0
331	1	1578	1
332	1	1579	0
332	1	1580	0
332	1	1581	0
332	1	1582	0
332	1	1583	1
333	1	1584	0
333	1	1585	0
333	1	1586	0
333	1	1587	1
334	1	1588	0
334	1	1589	0
334	1	1590	0
334	1	1591	1
335	1	1592	0
335	1	1593	0
335	1	1594	0
335	1	1595	0
335	1	1596	1
336	1	1597	0
336	1	1598	0
336	1	1599	0
336	1	1600	0
336	1	1601	1
337	1	1602	0
337	1	1603	0
337	1	1604	0
337	1	1605	1
338	1	1606	0
338	1	1607	0
338	1	1608	0
338	1	1609	0
338	1	1610	0
338	1	1611	1
650	1	3062	1
653	1	3075	0
658	1	3095	0
662	1	3110	0
664	1	3120	0
339	1	1612	0
339	1	1613	0
339	1	1614	0
339	1	1615	1
340	1	1616	0
340	1	1617	0
340	1	1618	0
340	1	1619	1
341	1	1620	0
341	1	1621	0
341	1	1622	0
341	1	1623	0
341	1	1624	0
341	1	1625	0
341	1	1626	0
341	1	1627	0
341	1	1628	0
341	1	1629	1
342	1	1630	0
342	1	1631	0
342	1	1632	0
342	1	1633	1
343	1	1634	0
343	1	1635	0
343	1	1636	0
343	1	1637	1
344	1	1638	0
344	1	1639	0
344	1	1640	0
344	1	1641	0
344	1	1642	1
345	1	1643	0
345	1	1644	0
345	1	1645	0
345	1	1646	1
346	1	1647	0
346	1	1648	0
346	1	1649	0
346	1	1650	0
346	1	1651	1
347	1	1652	0
347	1	1653	0
347	1	1654	0
347	1	1655	0
347	1	1656	0
347	1	1657	1
348	1	1658	0
348	1	1659	0
348	1	1660	1
349	1	1661	0
349	1	1662	0
349	1	1663	0
349	1	1664	0
349	1	1665	0
349	1	1666	0
349	1	1667	0
349	1	1668	0
349	1	1669	0
349	1	1670	0
349	1	1671	1
350	1	1672	0
350	1	1673	0
350	1	1674	0
350	1	1675	0
350	1	1676	1
351	1	1677	0
351	1	1678	0
351	1	1679	0
351	1	1680	1
352	1	1681	0
352	1	1682	0
352	1	1683	0
352	1	1684	1
353	1	1685	0
353	1	1686	0
353	1	1687	0
353	1	1688	1
354	1	1689	0
354	1	1690	0
354	1	1691	0
354	1	1692	0
354	1	1693	1
355	1	1694	0
355	1	1695	0
355	1	1696	0
355	1	1697	0
355	1	1698	0
355	1	1699	1
356	1	1700	0
356	1	1701	0
356	1	1702	0
356	1	1703	1
357	1	1704	0
357	1	1705	0
357	1	1706	0
357	1	1707	0
357	1	1708	1
358	1	1709	0
358	1	1710	0
358	1	1711	0
358	1	1712	1
359	1	1713	0
359	1	1714	0
359	1	1715	1
360	1	1716	0
360	1	1717	0
360	1	1718	0
360	1	1719	0
360	1	1720	0
360	1	1721	1
361	1	1722	0
361	1	1723	0
361	1	1724	0
361	1	1725	0
361	1	1726	1
362	1	1727	0
362	1	1728	0
362	1	1729	0
362	1	1730	1
363	1	1731	0
363	1	1732	0
363	1	1733	0
363	1	1734	1
364	1	1735	0
364	1	1736	0
364	1	1737	0
364	1	1738	0
364	1	1739	1
365	1	1740	0
365	1	1741	0
365	1	1742	0
365	1	1743	1
366	1	1744	0
366	1	1745	0
366	1	1746	0
366	1	1747	0
366	1	1748	0
366	1	1749	0
366	1	1750	0
366	1	1751	0
366	1	1752	0
366	1	1753	0
366	1	1754	1
367	1	1755	0
367	1	1756	0
367	1	1757	1
368	1	1758	0
368	1	1759	0
368	1	1760	0
368	1	1761	1
369	1	1762	0
369	1	1763	0
369	1	1764	0
369	1	1765	1
651	1	3063	0
653	1	3076	0
658	1	3096	1
662	1	3111	0
664	1	3121	0
370	1	1766	0
370	1	1767	0
370	1	1768	1
371	1	1769	0
371	1	1770	0
371	1	1771	0
371	1	1772	1
372	1	1773	0
372	1	1774	0
372	1	1775	0
372	1	1776	1
373	1	1777	0
373	1	1778	0
373	1	1779	0
373	1	1780	0
373	1	1781	1
374	1	1782	0
374	1	1783	0
374	1	1784	0
374	1	1785	1
375	1	1786	0
375	1	1787	0
375	1	1788	0
375	1	1789	1
376	1	1790	0
376	1	1791	0
376	1	1792	1
377	1	1793	0
377	1	1794	0
377	1	1795	0
377	1	1796	0
377	1	1797	1
378	1	1798	0
378	1	1799	0
378	1	1800	0
378	1	1801	1
379	1	1802	0
379	1	1803	0
379	1	1804	1
380	1	1805	0
380	1	1806	0
380	1	1807	0
380	1	1808	1
381	1	1809	0
381	1	1810	0
381	1	1811	0
381	1	1812	0
381	1	1813	1
382	1	1814	0
382	1	1815	0
382	1	1816	0
382	1	1817	1
383	1	1818	0
383	1	1819	0
383	1	1820	0
383	1	1821	1
384	1	1822	0
384	1	1823	0
384	1	1824	1
385	1	1825	0
385	1	1826	0
385	1	1827	1
386	1	1828	0
386	1	1829	0
386	1	1830	0
386	1	1831	0
386	1	1832	1
387	1	1833	0
387	1	1834	0
387	1	1835	0
387	1	1836	0
387	1	1837	0
387	1	1838	1
388	1	1839	0
388	1	1840	0
388	1	1841	0
388	1	1842	1
389	1	1843	0
389	1	1844	0
389	1	1845	0
389	1	1846	0
389	1	1847	0
389	1	1848	1
390	1	1849	0
390	1	1850	0
390	1	1851	0
390	1	1852	0
390	1	1853	0
390	1	1854	0
390	1	1855	0
390	1	1856	0
390	1	1857	1
391	1	1858	0
391	1	1859	0
391	1	1860	0
391	1	1861	1
392	1	1862	0
392	1	1863	0
392	1	1864	0
392	1	1865	0
392	1	1866	0
392	1	1867	1
393	1	1868	0
393	1	1869	0
393	1	1870	0
393	1	1871	0
393	1	1872	0
393	1	1873	1
394	1	1874	0
394	1	1875	0
394	1	1876	0
394	1	1877	1
395	1	1878	0
395	1	1879	0
395	1	1880	0
395	1	1881	1
396	1	1882	0
396	1	1883	0
396	1	1884	0
396	1	1885	0
396	1	1886	1
397	1	1887	0
397	1	1888	0
397	1	1889	0
397	1	1890	1
398	1	1891	0
398	1	1892	0
398	1	1893	0
398	1	1894	0
398	1	1895	1
399	1	1896	0
399	1	1897	0
399	1	1898	0
399	1	1899	0
399	1	1900	1
400	1	1901	0
400	1	1902	0
400	1	1903	1
401	1	1904	0
401	1	1905	0
401	1	1906	0
401	1	1907	0
401	1	1908	1
402	1	1909	0
402	1	1910	0
402	1	1911	0
402	1	1912	1
403	1	1913	0
403	1	1914	0
403	1	1915	0
403	1	1916	0
651	1	3064	0
653	1	3077	1
659	1	3097	0
662	1	3112	1
664	1	3122	0
403	1	1917	1
404	1	1918	0
404	1	1919	0
404	1	1920	0
404	1	1921	1
405	1	1922	0
405	1	1923	0
405	1	1924	0
405	1	1925	0
405	1	1926	1
406	1	1927	0
406	1	1928	0
406	1	1929	0
406	1	1930	0
406	1	1931	1
407	1	1932	0
407	1	1933	0
407	1	1934	0
407	1	1935	1
408	1	1936	0
408	1	1937	0
408	1	1938	0
408	1	1939	0
408	1	1940	1
409	1	1941	0
409	1	1942	0
409	1	1943	0
409	1	1944	0
409	1	1945	0
409	1	1946	1
410	1	1947	0
410	1	1948	0
410	1	1949	0
410	1	1950	1
411	1	1951	0
411	1	1952	0
411	1	1953	0
411	1	1954	1
412	1	1955	0
412	1	1956	0
412	1	1957	0
412	1	1958	0
412	1	1959	1
413	1	1960	0
413	1	1961	0
413	1	1962	0
413	1	1963	1
414	1	1964	0
414	1	1965	0
414	1	1966	0
414	1	1967	1
415	1	1968	0
415	1	1969	0
415	1	1970	1
416	1	1971	0
416	1	1972	0
416	1	1973	0
416	1	1974	1
417	1	1975	0
417	1	1976	0
417	1	1977	0
417	1	1978	0
417	1	1979	1
418	1	1980	0
418	1	1981	0
418	1	1982	0
418	1	1983	1
419	1	1984	0
419	1	1985	0
419	1	1986	1
420	1	1987	0
420	1	1988	0
420	1	1989	0
420	1	1990	0
420	1	1991	1
421	1	1992	0
421	1	1993	0
421	1	1994	0
421	1	1995	0
421	1	1996	1
422	1	1997	0
422	1	1998	0
422	1	1999	1
423	1	2000	0
606	1	2852	0
606	1	2853	0
606	1	2854	0
606	1	2855	0
606	1	2856	1
607	1	2857	0
607	1	2858	0
607	1	2859	1
608	1	2860	0
608	1	2861	0
608	1	2862	0
608	1	2863	0
608	1	2864	0
608	1	2865	0
608	1	2866	1
609	1	2867	0
609	1	2868	0
609	1	2869	1
610	1	2870	0
610	1	2871	0
610	1	2872	0
610	1	2873	0
610	1	2874	1
611	1	2875	0
611	1	2876	0
611	1	2877	0
611	1	2878	0
611	1	2879	0
611	1	2880	1
612	1	2881	0
612	1	2882	0
612	1	2883	1
613	1	2884	0
613	1	2885	0
613	1	2886	1
614	1	2887	0
614	1	2888	0
614	1	2889	0
614	1	2890	0
614	1	2891	1
615	1	2892	0
615	1	2893	0
615	1	2894	0
615	1	2895	0
615	1	2896	0
615	1	2897	1
616	1	2898	0
616	1	2899	0
616	1	2900	1
617	1	2901	0
617	1	2902	0
617	1	2903	1
618	1	2904	0
618	1	2905	0
618	1	2906	0
618	1	2907	0
618	1	2908	0
618	1	2909	0
618	1	2910	0
618	1	2911	1
619	1	2912	0
619	1	2913	0
619	1	2914	0
619	1	2915	1
620	1	2916	0
620	1	2917	0
620	1	2918	0
620	1	2919	1
621	1	2920	0
621	1	2921	0
621	1	2922	0
621	1	2923	1
622	1	2924	0
622	1	2925	0
622	1	2926	0
622	1	2927	1
623	1	2928	0
623	1	2929	0
623	1	2930	0
623	1	2931	0
623	1	2932	1
651	1	3065	0
654	1	3078	0
659	1	3098	0
663	1	3113	0
664	1	3123	0
423	1	2001	0
423	1	2002	0
423	1	2003	1
424	1	2004	0
424	1	2005	0
424	1	2006	0
424	1	2007	1
425	1	2008	0
425	1	2009	0
425	1	2010	0
425	1	2011	0
425	1	2012	1
426	1	2013	0
426	1	2014	0
426	1	2015	0
426	1	2016	0
426	1	2017	0
426	1	2018	1
427	1	2019	0
427	1	2020	0
427	1	2021	0
427	1	2022	1
428	1	2023	0
428	1	2024	0
428	1	2025	0
428	1	2026	0
428	1	2027	1
429	1	2028	0
429	1	2029	0
429	1	2030	0
429	1	2031	0
429	1	2032	1
430	1	2033	0
430	1	2034	0
430	1	2035	0
430	1	2036	0
430	1	2037	0
430	1	2038	1
431	1	2039	0
431	1	2040	0
431	1	2041	0
431	1	2042	1
432	1	2043	0
432	1	2044	0
432	1	2045	0
432	1	2046	0
432	1	2047	1
433	1	2048	0
433	1	2049	0
433	1	2050	0
433	1	2051	1
434	1	2052	0
434	1	2053	0
434	1	2054	1
435	1	2055	0
435	1	2056	0
435	1	2057	0
435	1	2058	1
436	1	2059	0
436	1	2060	0
436	1	2061	0
436	1	2062	1
437	1	2063	0
437	1	2064	0
437	1	2065	0
437	1	2066	0
437	1	2067	0
437	1	2068	1
438	1	2069	0
438	1	2070	0
438	1	2071	0
438	1	2072	1
439	1	2073	0
439	1	2074	0
439	1	2075	0
439	1	2076	1
440	1	2077	0
440	1	2078	0
440	1	2079	0
440	1	2080	0
440	1	2081	1
441	1	2082	0
441	1	2083	0
441	1	2084	0
441	1	2085	0
441	1	2086	0
441	1	2087	0
441	1	2088	1
442	1	2089	0
442	1	2090	0
442	1	2091	0
442	1	2092	0
442	1	2093	1
443	1	2094	0
443	1	2095	0
443	1	2096	0
443	1	2097	1
444	1	2098	0
444	1	2099	0
444	1	2100	1
445	1	2101	0
445	1	2102	0
445	1	2103	0
445	1	2104	1
446	1	2105	0
446	1	2106	0
446	1	2107	0
446	1	2108	0
446	1	2109	1
447	1	2110	0
447	1	2111	0
447	1	2112	1
448	1	2113	0
448	1	2114	0
448	1	2115	0
448	1	2116	0
448	1	2117	0
448	1	2118	0
448	1	2119	1
449	1	2120	0
449	1	2121	0
449	1	2122	0
449	1	2123	0
449	1	2124	1
450	1	2125	0
450	1	2126	0
450	1	2127	1
451	1	2128	0
451	1	2129	0
451	1	2130	0
451	1	2131	0
451	1	2132	0
451	1	2133	0
451	1	2134	0
451	1	2135	1
452	1	2136	0
452	1	2137	0
452	1	2138	0
452	1	2139	0
452	1	2140	1
453	1	2141	0
453	1	2142	0
453	1	2143	0
453	1	2144	1
454	1	2145	0
454	1	2146	0
454	1	2147	1
455	1	2148	0
455	1	2149	0
455	1	2150	0
455	1	2151	0
455	1	2152	0
455	1	2153	0
651	1	3066	1
654	1	3079	0
659	1	3099	1
664	1	3124	1
455	1	2154	1
456	1	2155	0
456	1	2156	0
456	1	2157	0
456	1	2158	0
456	1	2159	0
456	1	2160	1
457	1	2161	0
457	1	2162	0
457	1	2163	1
458	1	2164	0
458	1	2165	0
458	1	2166	0
458	1	2167	1
459	1	2168	0
459	1	2169	0
459	1	2170	0
459	1	2171	1
460	1	2172	0
460	1	2173	0
460	1	2174	0
460	1	2175	0
460	1	2176	1
461	1	2177	0
461	1	2178	0
461	1	2179	1
462	1	2180	0
462	1	2181	0
462	1	2182	0
462	1	2183	1
463	1	2184	0
463	1	2185	0
463	1	2186	0
463	1	2187	0
463	1	2188	0
463	1	2189	0
463	1	2190	1
464	1	2191	0
464	1	2192	0
464	1	2193	0
464	1	2194	0
464	1	2195	0
464	1	2196	0
464	1	2197	1
465	1	2198	0
465	1	2199	0
465	1	2200	0
465	1	2201	1
466	1	2202	0
466	1	2203	0
466	1	2204	0
466	1	2205	0
466	1	2206	1
467	1	2207	0
467	1	2208	0
467	1	2209	0
467	1	2210	0
467	1	2211	0
467	1	2212	0
467	1	2213	0
467	1	2214	0
467	1	2215	1
468	1	2216	0
468	1	2217	0
468	1	2218	0
468	1	2219	1
469	1	2220	0
469	1	2221	0
469	1	2222	0
469	1	2223	0
469	1	2224	0
469	1	2225	1
470	1	2226	0
470	1	2227	0
470	1	2228	0
470	1	2229	1
471	1	2230	0
471	1	2231	0
471	1	2232	0
471	1	2233	1
472	1	2234	0
472	1	2235	0
472	1	2236	0
472	1	2237	1
473	1	2238	0
473	1	2239	0
473	1	2240	0
473	1	2241	1
474	1	2242	0
474	1	2243	0
474	1	2244	0
474	1	2245	1
475	1	2246	0
475	1	2247	0
475	1	2248	0
475	1	2249	1
476	1	2250	0
476	1	2251	0
476	1	2252	0
476	1	2253	0
476	1	2254	0
476	1	2255	1
477	1	2256	0
477	1	2257	0
477	1	2258	0
477	1	2259	0
477	1	2260	0
477	1	2261	0
477	1	2262	1
478	1	2263	0
478	1	2264	0
478	1	2265	0
478	1	2266	1
479	1	2267	0
479	1	2268	0
479	1	2269	0
479	1	2270	1
480	1	2271	0
480	1	2272	0
480	1	2273	0
480	1	2274	1
481	1	2275	0
481	1	2276	0
481	1	2277	0
481	1	2278	0
481	1	2279	0
481	1	2280	1
482	1	2281	0
482	1	2282	0
482	1	2283	0
482	1	2284	1
483	1	2285	0
483	1	2286	0
483	1	2287	0
483	1	2288	1
484	1	2289	0
484	1	2290	0
484	1	2291	0
484	1	2292	1
485	1	2293	0
485	1	2294	0
485	1	2295	0
485	1	2296	1
486	1	2297	0
486	1	2298	0
486	1	2299	0
486	1	2300	1
487	1	2301	0
487	1	2302	0
487	1	2303	0
487	1	2304	0
487	1	2305	1
652	1	3067	0
654	1	3080	1
660	1	3100	0
663	1	3114	0
665	1	3125	0
488	1	2306	0
488	1	2307	0
488	1	2308	1
489	1	2309	0
489	1	2310	0
489	1	2311	0
489	1	2312	0
489	1	2313	1
490	1	2314	0
490	1	2315	0
490	1	2316	1
491	1	2317	0
491	1	2318	0
491	1	2319	0
491	1	2320	0
491	1	2321	0
491	1	2322	0
491	1	2323	1
492	1	2324	0
492	1	2325	0
492	1	2326	0
492	1	2327	0
492	1	2328	0
492	1	2329	1
493	1	2330	0
493	1	2331	0
493	1	2332	0
493	1	2333	0
493	1	2334	1
494	1	2335	0
494	1	2336	0
494	1	2337	0
494	1	2338	0
494	1	2339	1
495	1	2340	0
495	1	2341	0
495	1	2342	0
495	1	2343	0
495	1	2344	1
496	1	2345	0
496	1	2346	0
496	1	2347	1
497	1	2348	0
497	1	2349	0
497	1	2350	1
498	1	2351	0
498	1	2352	0
498	1	2353	0
498	1	2354	1
499	1	2355	0
499	1	2356	0
499	1	2357	0
499	1	2358	1
500	1	2359	0
500	1	2360	0
500	1	2361	0
500	1	2362	0
500	1	2363	0
500	1	2364	1
501	1	2365	0
501	1	2366	0
501	1	2367	0
501	1	2368	0
501	1	2369	0
501	1	2370	0
501	1	2371	1
502	1	2372	0
502	1	2373	0
502	1	2374	0
502	1	2375	1
503	1	2376	0
503	1	2377	0
503	1	2378	0
503	1	2379	0
503	1	2380	1
504	1	2381	0
504	1	2382	0
504	1	2383	0
504	1	2384	0
504	1	2385	1
505	1	2386	0
505	1	2387	0
505	1	2388	0
505	1	2389	0
505	1	2390	1
506	1	2391	0
506	1	2392	0
506	1	2393	0
506	1	2394	1
507	1	2395	0
507	1	2396	0
507	1	2397	0
507	1	2398	0
507	1	2399	0
507	1	2400	0
507	1	2401	0
507	1	2402	0
507	1	2403	1
508	1	2404	0
508	1	2405	0
508	1	2406	0
508	1	2407	0
508	1	2408	1
509	1	2409	0
509	1	2410	0
509	1	2411	0
509	1	2412	1
510	1	2413	0
510	1	2414	0
510	1	2415	1
511	1	2416	0
511	1	2417	0
511	1	2418	0
511	1	2419	1
512	1	2420	0
512	1	2421	0
512	1	2422	0
512	1	2423	0
512	1	2424	1
513	1	2425	0
513	1	2426	0
513	1	2427	0
513	1	2428	0
513	1	2429	1
514	1	2430	0
514	1	2431	0
514	1	2432	0
514	1	2433	0
514	1	2434	0
514	1	2435	1
515	1	2436	0
515	1	2437	0
515	1	2438	1
516	1	2439	0
516	1	2440	0
516	1	2441	0
516	1	2442	1
517	1	2443	0
517	1	2444	0
517	1	2445	0
517	1	2446	1
518	1	2447	0
518	1	2448	0
518	1	2449	0
518	1	2450	0
518	1	2451	1
519	1	2452	0
519	1	2453	0
519	1	2454	0
519	1	2455	1
520	1	2456	0
520	1	2457	0
520	1	2458	0
652	1	3068	0
655	1	3081	0
660	1	3101	0
665	1	3126	0
520	1	2459	0
520	1	2460	0
520	1	2461	1
521	1	2462	0
521	1	2463	0
521	1	2464	0
521	1	2465	1
522	1	2466	0
522	1	2467	0
522	1	2468	1
523	1	2469	0
523	1	2470	0
523	1	2471	0
523	1	2472	1
524	1	2473	0
524	1	2474	0
524	1	2475	0
524	1	2476	1
525	1	2477	0
525	1	2478	0
525	1	2479	0
525	1	2480	1
526	1	2481	0
526	1	2482	0
526	1	2483	0
526	1	2484	0
526	1	2485	1
527	1	2486	0
527	1	2487	0
527	1	2488	0
527	1	2489	0
527	1	2490	0
527	1	2491	1
528	1	2492	0
528	1	2493	0
528	1	2494	0
528	1	2495	1
529	1	2496	0
529	1	2497	0
529	1	2498	0
529	1	2499	0
529	1	2500	1
530	1	2501	0
530	1	2502	0
530	1	2503	0
530	1	2504	1
531	1	2505	0
531	1	2506	0
531	1	2507	0
531	1	2508	1
532	1	2509	0
532	1	2510	0
532	1	2511	1
533	1	2512	0
533	1	2513	0
533	1	2514	0
533	1	2515	0
533	1	2516	0
533	1	2517	0
533	1	2518	1
534	1	2519	0
534	1	2520	0
534	1	2521	0
534	1	2522	0
534	1	2523	1
535	1	2524	0
535	1	2525	0
535	1	2526	0
535	1	2527	1
536	1	2528	0
536	1	2529	0
536	1	2530	0
536	1	2531	0
536	1	2532	0
536	1	2533	1
537	1	2534	0
537	1	2535	0
537	1	2536	0
537	1	2537	0
537	1	2538	0
537	1	2539	1
538	1	2540	0
538	1	2541	0
538	1	2542	0
538	1	2543	1
539	1	2544	0
539	1	2545	0
539	1	2546	1
540	1	2547	0
540	1	2548	0
540	1	2549	0
540	1	2550	0
540	1	2551	1
541	1	2552	0
541	1	2553	0
541	1	2554	0
541	1	2555	1
542	1	2556	0
542	1	2557	0
542	1	2558	0
542	1	2559	1
543	1	2560	0
543	1	2561	0
543	1	2562	0
543	1	2563	1
544	1	2564	0
544	1	2565	0
544	1	2566	0
544	1	2567	1
545	1	2568	0
545	1	2569	0
545	1	2570	1
546	1	2571	0
546	1	2572	0
546	1	2573	1
547	1	2574	0
547	1	2575	0
547	1	2576	0
547	1	2577	0
547	1	2578	1
548	1	2579	0
548	1	2580	0
548	1	2581	0
548	1	2582	0
548	1	2583	0
548	1	2584	0
548	1	2585	0
548	1	2586	0
548	1	2587	1
549	1	2588	0
549	1	2589	0
549	1	2590	0
549	1	2591	0
549	1	2592	1
550	1	2593	0
550	1	2594	0
550	1	2595	0
550	1	2596	0
550	1	2597	1
551	1	2598	0
551	1	2599	0
551	1	2600	0
551	1	2601	1
552	1	2602	0
552	1	2603	0
552	1	2604	1
553	1	2605	0
553	1	2606	0
553	1	2607	0
553	1	2608	0
553	1	2609	0
553	1	2610	0
652	1	3069	1
655	1	3082	0
660	1	3102	0
665	1	3127	0
553	1	2611	1
554	1	2612	0
554	1	2613	0
554	1	2614	0
554	1	2615	0
554	1	2616	1
555	1	2617	0
555	1	2618	0
555	1	2619	0
555	1	2620	0
555	1	2621	0
555	1	2622	0
555	1	2623	0
555	1	2624	1
556	1	2625	0
556	1	2626	0
556	1	2627	0
556	1	2628	0
556	1	2629	1
557	1	2630	0
557	1	2631	0
557	1	2632	1
558	1	2633	0
558	1	2634	0
558	1	2635	1
559	1	2636	0
559	1	2637	0
559	1	2638	0
559	1	2639	0
559	1	2640	0
559	1	2641	1
560	1	2642	0
560	1	2643	0
560	1	2644	0
560	1	2645	0
560	1	2646	1
561	1	2647	0
561	1	2648	0
561	1	2649	0
561	1	2650	0
561	1	2651	0
561	1	2652	0
561	1	2653	1
562	1	2654	0
562	1	2655	0
562	1	2656	1
563	1	2657	0
563	1	2658	0
563	1	2659	0
563	1	2660	1
564	1	2661	0
564	1	2662	0
564	1	2663	0
564	1	2664	0
564	1	2665	0
564	1	2666	1
565	1	2667	0
565	1	2668	0
565	1	2669	0
565	1	2670	0
565	1	2671	1
566	1	2672	0
566	1	2673	0
566	1	2674	0
566	1	2675	1
567	1	2676	0
567	1	2677	0
567	1	2678	1
568	1	2679	0
568	1	2680	0
568	1	2681	0
568	1	2682	1
569	1	2683	0
569	1	2684	0
569	1	2685	0
569	1	2686	1
570	1	2687	0
570	1	2688	0
570	1	2689	0
570	1	2690	1
571	1	2691	0
571	1	2692	0
571	1	2693	0
571	1	2694	1
572	1	2695	0
572	1	2696	0
572	1	2697	1
573	1	2698	0
573	1	2699	0
573	1	2700	0
573	1	2701	1
574	1	2702	0
574	1	2703	0
574	1	2704	0
574	1	2705	1
575	1	2706	0
575	1	2707	0
575	1	2708	0
575	1	2709	0
575	1	2710	1
576	1	2711	0
576	1	2712	0
576	1	2713	0
576	1	2714	0
576	1	2715	0
576	1	2716	1
577	1	2717	0
577	1	2718	0
577	1	2719	0
577	1	2720	0
577	1	2721	1
578	1	2722	0
578	1	2723	0
578	1	2724	0
578	1	2725	0
578	1	2726	1
579	1	2727	0
579	1	2728	0
579	1	2729	0
579	1	2730	1
580	1	2731	0
580	1	2732	0
580	1	2733	0
580	1	2734	1
581	1	2735	0
581	1	2736	0
581	1	2737	0
581	1	2738	0
581	1	2739	1
582	1	2740	0
582	1	2741	0
582	1	2742	0
582	1	2743	0
582	1	2744	1
583	1	2745	0
583	1	2746	0
583	1	2747	0
583	1	2748	1
584	1	2749	0
584	1	2750	0
584	1	2751	0
584	1	2752	1
585	1	2753	0
585	1	2754	0
585	1	2755	0
585	1	2756	1
586	1	2757	0
586	1	2758	0
586	1	2759	0
586	1	2760	1
587	1	2761	0
655	1	3083	0
660	1	3103	1
665	1	3128	1
655	1	3084	0
27	1	133	0
661	1	3104	0
666	1	3129	0
27	1	134	0
1	1	1	0
1	1	2	0
1	1	3	0
1	1	4	0
1	1	5	0
1	1	6	0
1	1	7	1
2	1	8	0
2	1	9	0
2	1	10	0
2	1	11	1
3	1	12	0
3	1	13	0
3	1	14	0
3	1	15	0
3	1	16	0
3	1	17	0
3	1	18	1
4	1	19	0
4	1	20	0
4	1	21	0
4	1	22	0
4	1	23	0
4	1	24	1
5	1	25	0
5	1	26	0
5	1	27	1
6	1	28	0
6	1	29	0
6	1	30	0
6	1	31	1
7	1	32	0
7	1	33	0
7	1	34	0
7	1	35	0
7	1	36	0
7	1	37	1
8	1	38	0
8	1	39	0
8	1	40	0
8	1	41	1
9	1	42	0
9	1	43	0
9	1	44	0
9	1	45	1
10	1	46	0
10	1	47	0
10	1	48	0
10	1	49	0
10	1	50	1
11	1	51	0
11	1	52	0
11	1	53	0
11	1	54	0
11	1	55	0
11	1	56	0
11	1	57	0
11	1	58	0
11	1	59	1
12	1	60	0
12	1	61	0
12	1	62	0
12	1	63	0
12	1	64	1
13	1	65	0
13	1	66	0
13	1	67	0
13	1	68	1
14	1	69	0
14	1	70	0
14	1	71	1
15	1	72	0
15	1	73	0
15	1	74	0
15	1	75	0
15	1	76	1
16	1	77	0
16	1	78	0
16	1	79	0
16	1	80	0
16	1	81	1
17	1	82	0
17	1	83	0
17	1	84	0
17	1	85	1
18	1	86	0
18	1	87	0
18	1	88	0
18	1	89	0
18	1	90	0
18	1	91	0
18	1	92	0
18	1	93	1
19	1	94	0
19	1	95	0
19	1	96	0
19	1	97	0
19	1	98	0
19	1	99	1
20	1	100	0
20	1	101	0
20	1	102	0
20	1	103	0
20	1	104	1
21	1	105	0
21	1	106	0
21	1	107	0
21	1	108	0
21	1	109	1
22	1	110	0
22	1	111	0
22	1	112	0
22	1	113	0
22	1	114	0
22	1	115	1
23	1	116	0
23	1	117	0
23	1	118	0
23	1	119	0
23	1	120	1
24	1	121	0
24	1	122	0
24	1	123	0
24	1	124	1
25	1	125	0
25	1	126	0
25	1	127	0
25	1	128	1
26	1	129	0
26	1	130	0
26	1	131	0
26	1	132	1
27	1	135	0
27	1	136	1
28	1	137	0
28	1	138	0
28	1	139	1
29	1	140	0
29	1	141	0
29	1	142	0
29	1	143	0
29	1	144	1
30	1	145	0
30	1	146	0
30	1	147	0
30	1	148	0
30	1	149	1
31	1	150	0
31	1	151	0
31	1	152	0
31	1	153	1
32	1	154	0
32	1	155	0
32	1	156	0
32	1	157	0
32	1	158	1
33	1	159	0
33	1	160	0
33	1	161	0
33	1	162	0
33	1	163	1
34	1	164	0
34	1	165	0
34	1	166	0
34	1	167	0
34	1	168	1
35	1	169	0
35	1	170	0
35	1	171	0
35	1	172	0
35	1	173	0
35	1	174	0
35	1	175	1
36	1	176	0
36	1	177	0
36	1	178	0
36	1	179	0
36	1	180	1
37	1	181	0
37	1	182	0
37	1	183	0
37	1	184	0
37	1	185	1
38	1	186	0
38	1	187	0
38	1	188	0
38	1	189	0
38	1	190	1
39	1	191	0
39	1	192	0
39	1	193	0
39	1	194	1
40	1	195	0
40	1	196	0
40	1	197	0
40	1	198	1
41	1	199	0
41	1	200	0
41	1	201	0
41	1	202	0
41	1	203	1
42	1	204	0
42	1	205	0
42	1	206	0
42	1	207	1
43	1	208	0
43	1	209	0
43	1	210	0
43	1	211	0
43	1	212	1
44	1	213	0
44	1	214	0
44	1	215	0
44	1	216	1
45	1	217	0
45	1	218	0
45	1	219	0
45	1	220	0
45	1	221	1
46	1	222	0
46	1	223	0
46	1	224	0
46	1	225	0
46	1	226	1
47	1	227	0
47	1	228	0
47	1	229	0
47	1	230	1
48	1	231	0
48	1	232	0
48	1	233	0
48	1	234	0
48	1	235	0
48	1	236	0
48	1	237	1
49	1	238	0
49	1	239	0
49	1	240	0
49	1	241	1
50	1	242	0
50	1	243	0
50	1	244	1
51	1	245	0
51	1	246	0
51	1	247	0
51	1	248	1
52	1	249	0
52	1	250	0
52	1	251	0
52	1	252	0
52	1	253	0
52	1	254	1
53	1	255	0
53	1	256	0
53	1	257	0
53	1	258	0
53	1	259	0
53	1	260	1
54	1	261	0
54	1	262	0
54	1	263	0
54	1	264	1
55	1	265	0
55	1	266	0
55	1	267	0
55	1	268	1
56	1	269	0
56	1	270	0
56	1	271	1
57	1	272	0
57	1	273	0
57	1	274	0
57	1	275	1
58	1	276	0
58	1	277	0
58	1	278	0
58	1	279	0
58	1	280	0
58	1	281	1
59	1	282	0
59	1	283	0
59	1	284	0
59	1	285	0
59	1	286	0
59	1	287	1
60	1	288	0
60	1	289	0
60	1	290	0
60	1	291	0
60	1	292	1
61	1	293	0
61	1	294	0
61	1	295	1
62	1	296	0
62	1	297	0
62	1	298	0
62	1	299	1
63	1	300	0
63	1	301	0
63	1	302	0
63	1	303	0
63	1	304	1
64	1	305	0
64	1	306	0
64	1	307	0
655	1	3085	1
666	1	3130	0
64	1	308	0
64	1	309	0
64	1	310	0
64	1	311	1
65	1	312	0
65	1	313	0
65	1	314	0
65	1	315	0
65	1	316	1
66	1	317	0
66	1	318	0
66	1	319	0
66	1	320	0
66	1	321	0
66	1	322	1
67	1	323	0
67	1	324	0
67	1	325	0
67	1	326	1
68	1	327	0
68	1	328	0
68	1	329	0
68	1	330	0
68	1	331	0
68	1	332	1
69	1	333	0
69	1	334	0
69	1	335	0
69	1	336	0
69	1	337	0
69	1	338	0
69	1	339	1
70	1	340	0
70	1	341	0
70	1	342	0
70	1	343	0
70	1	344	0
70	1	345	0
70	1	346	1
71	1	347	0
71	1	348	0
71	1	349	0
71	1	350	1
72	1	351	0
72	1	352	0
72	1	353	0
72	1	354	0
72	1	355	1
73	1	356	0
73	1	357	0
73	1	358	0
73	1	359	0
73	1	360	1
74	1	361	0
74	1	362	0
74	1	363	0
74	1	364	0
74	1	365	1
75	1	366	0
75	1	367	0
75	1	368	0
75	1	369	0
75	1	370	1
76	1	371	0
76	1	372	0
76	1	373	0
76	1	374	1
77	1	375	0
77	1	376	0
77	1	377	0
77	1	378	1
78	1	379	0
78	1	380	0
78	1	381	0
78	1	382	0
78	1	383	0
78	1	384	1
79	1	385	0
79	1	386	0
79	1	387	0
79	1	388	1
80	1	389	0
80	1	390	0
80	1	391	1
81	1	392	0
81	1	393	0
81	1	394	0
81	1	395	0
81	1	396	0
81	1	397	0
81	1	398	0
81	1	399	1
82	1	400	0
82	1	401	0
82	1	402	0
82	1	403	0
82	1	404	1
83	1	405	0
83	1	406	0
83	1	407	0
83	1	408	1
84	1	409	0
84	1	410	0
84	1	411	0
84	1	412	1
85	1	413	0
85	1	414	0
85	1	415	0
85	1	416	0
85	1	417	0
85	1	418	0
85	1	419	1
86	1	420	0
86	1	421	0
86	1	422	0
86	1	423	0
86	1	424	0
86	1	425	0
86	1	426	0
86	1	427	1
87	1	428	0
87	1	429	0
87	1	430	0
87	1	431	0
87	1	432	1
88	1	433	0
88	1	434	0
88	1	435	0
88	1	436	1
89	1	437	0
89	1	438	0
89	1	439	1
90	1	440	0
90	1	441	0
90	1	442	1
91	1	443	0
91	1	444	0
91	1	445	0
91	1	446	1
92	1	447	0
92	1	448	0
92	1	449	0
92	1	450	1
93	1	451	0
93	1	452	0
93	1	453	0
93	1	454	0
93	1	455	0
93	1	456	0
93	1	457	1
94	1	458	0
94	1	459	0
94	1	460	0
94	1	461	0
94	1	462	0
656	1	3086	0
666	1	3131	0
94	1	463	1
95	1	464	0
95	1	465	0
95	1	466	0
95	1	467	1
96	1	468	0
96	1	469	0
96	1	470	0
96	1	471	1
97	1	472	0
97	1	473	0
97	1	474	1
98	1	475	0
98	1	476	0
98	1	477	0
98	1	478	1
99	1	479	0
99	1	480	0
99	1	481	1
100	1	482	0
100	1	483	0
100	1	484	0
100	1	485	1
101	1	486	0
101	1	487	0
101	1	488	0
101	1	489	0
101	1	490	1
102	1	491	0
102	1	492	0
102	1	493	1
103	1	494	0
103	1	495	0
103	1	496	0
103	1	497	0
103	1	498	0
103	1	499	1
104	1	500	0
104	1	501	0
104	1	502	0
104	1	503	0
104	1	504	0
104	1	505	1
105	1	506	0
105	1	507	0
105	1	508	1
106	1	509	0
106	1	510	0
106	1	511	0
106	1	512	1
107	1	513	0
107	1	514	0
107	1	515	0
107	1	516	0
107	1	517	0
107	1	518	1
108	1	519	0
108	1	520	0
108	1	521	0
108	1	522	0
108	1	523	1
109	1	524	0
109	1	525	0
109	1	526	1
110	1	527	0
110	1	528	0
110	1	529	0
110	1	530	0
110	1	531	1
111	1	532	0
111	1	533	0
111	1	534	0
111	1	535	1
112	1	536	0
112	1	537	0
112	1	538	0
112	1	539	1
113	1	540	0
113	1	541	0
113	1	542	0
113	1	543	0
113	1	544	1
114	1	545	0
114	1	546	0
114	1	547	0
114	1	548	0
114	1	549	1
115	1	550	0
115	1	551	0
115	1	552	0
115	1	553	0
115	1	554	1
116	1	555	0
116	1	556	0
116	1	557	0
116	1	558	1
117	1	559	0
117	1	560	0
117	1	561	0
117	1	562	1
118	1	563	0
118	1	564	0
118	1	565	0
118	1	566	0
118	1	567	1
119	1	568	0
119	1	569	0
119	1	570	0
119	1	571	1
120	1	572	0
120	1	573	0
120	1	574	0
120	1	575	0
120	1	576	0
120	1	577	1
121	1	578	0
121	1	579	0
121	1	580	0
121	1	581	1
122	1	582	0
122	1	583	0
122	1	584	1
123	1	585	0
123	1	586	0
123	1	587	1
124	1	588	0
124	1	589	0
124	1	590	1
125	1	591	0
125	1	592	0
125	1	593	0
125	1	594	0
125	1	595	1
126	1	596	0
126	1	597	0
126	1	598	0
126	1	599	1
127	1	600	0
127	1	601	0
127	1	602	0
127	1	603	0
127	1	604	1
128	1	605	0
128	1	606	0
128	1	607	0
128	1	608	1
129	1	609	0
129	1	610	0
129	1	611	0
129	1	612	0
656	1	3087	0
666	1	3132	1
129	1	613	0
129	1	614	0
129	1	615	1
130	1	616	0
130	1	617	0
130	1	618	0
130	1	619	0
130	1	620	1
131	1	621	0
131	1	622	0
131	1	623	0
131	1	624	0
131	1	625	0
131	1	626	1
132	1	627	0
132	1	628	0
132	1	629	0
132	1	630	0
132	1	631	1
133	1	632	0
133	1	633	0
133	1	634	1
134	1	635	0
134	1	636	0
134	1	637	0
134	1	638	0
134	1	639	0
134	1	640	0
134	1	641	0
134	1	642	0
134	1	643	0
134	1	644	1
135	1	645	0
135	1	646	0
135	1	647	0
135	1	648	0
135	1	649	0
135	1	650	0
135	1	651	0
135	1	652	0
135	1	653	1
136	1	654	0
136	1	655	0
136	1	656	0
136	1	657	1
137	1	658	0
137	1	659	0
137	1	660	0
137	1	661	0
137	1	662	1
138	1	663	0
138	1	664	0
138	1	665	0
138	1	666	0
138	1	667	1
139	1	668	0
139	1	669	0
139	1	670	0
139	1	671	0
139	1	672	0
139	1	673	0
139	1	674	1
140	1	675	0
140	1	676	0
140	1	677	0
140	1	678	1
141	1	679	0
141	1	680	0
141	1	681	0
141	1	682	1
142	1	683	0
142	1	684	0
142	1	685	0
142	1	686	0
142	1	687	1
143	1	688	0
143	1	689	0
143	1	690	1
144	1	691	0
144	1	692	0
144	1	693	0
144	1	694	0
144	1	695	1
145	1	696	0
145	1	697	0
145	1	698	0
145	1	699	0
145	1	700	0
145	1	701	1
146	1	702	0
146	1	703	0
146	1	704	0
146	1	705	0
146	1	706	1
147	1	707	0
147	1	708	0
147	1	709	0
147	1	710	0
147	1	711	1
148	1	712	0
148	1	713	0
148	1	714	1
149	1	715	0
149	1	716	0
149	1	717	0
149	1	718	0
149	1	719	0
149	1	720	0
149	1	721	0
149	1	722	1
150	1	723	0
150	1	724	0
150	1	725	0
150	1	726	0
150	1	727	1
151	1	728	0
151	1	729	0
151	1	730	0
151	1	731	0
151	1	732	0
151	1	733	1
152	1	734	0
152	1	735	0
587	1	2762	0
587	1	2763	0
587	1	2764	1
588	1	2765	0
588	1	2766	0
588	1	2767	0
588	1	2768	0
588	1	2769	1
589	1	2770	0
589	1	2771	0
589	1	2772	0
589	1	2773	1
590	1	2774	0
590	1	2775	0
590	1	2776	0
590	1	2777	0
590	1	2778	0
590	1	2779	0
590	1	2780	0
590	1	2781	1
591	1	2782	0
591	1	2783	0
591	1	2784	0
591	1	2785	1
592	1	2786	0
592	1	2787	0
592	1	2788	0
592	1	2789	1
593	1	2790	0
593	1	2791	0
593	1	2792	0
593	1	2793	0
593	1	2794	0
656	1	3088	0
667	1	3133	0
624	1	2933	0
624	1	2934	0
624	1	2935	0
624	1	2936	0
624	1	2937	1
625	1	2938	0
625	1	2939	0
625	1	2940	0
625	1	2941	0
625	1	2942	1
626	1	2943	0
626	1	2944	0
626	1	2945	0
626	1	2946	1
627	1	2947	0
627	1	2948	0
627	1	2949	0
627	1	2950	1
628	1	2951	0
628	1	2952	0
628	1	2953	0
628	1	2954	1
629	1	2955	0
629	1	2956	0
629	1	2957	1
630	1	2958	0
630	1	2959	0
630	1	2960	0
630	1	2961	1
631	1	2962	0
631	1	2963	0
631	1	2964	0
631	1	2965	1
632	1	2966	0
632	1	2967	0
632	1	2968	0
632	1	2969	0
632	1	2970	0
632	1	2971	1
633	1	2972	0
633	1	2973	0
633	1	2974	0
633	1	2975	0
633	1	2976	0
633	1	2977	1
634	1	2978	0
634	1	2979	0
634	1	2980	0
634	1	2981	0
634	1	2982	0
634	1	2983	1
635	1	2984	0
635	1	2985	0
635	1	2986	0
635	1	2987	1
636	1	2988	0
636	1	2989	0
636	1	2990	0
636	1	2991	0
636	1	2992	1
637	1	2993	0
637	1	2994	0
637	1	2995	0
637	1	2996	1
638	1	2997	0
638	1	2998	0
638	1	2999	0
638	1	3000	1
639	1	3001	0
639	1	3002	0
639	1	3003	0
639	1	3004	0
639	1	3005	0
639	1	3006	0
639	1	3007	0
639	1	3008	0
639	1	3009	0
639	1	3010	1
640	1	3011	0
640	1	3012	0
640	1	3013	0
640	1	3014	1
641	1	3015	0
641	1	3016	0
641	1	3017	1
642	1	3018	0
642	1	3019	0
642	1	3020	0
642	1	3021	1
643	1	3022	0
643	1	3023	0
643	1	3024	0
643	1	3025	0
643	1	3026	1
644	1	3027	0
644	1	3028	0
644	1	3029	1
645	1	3030	0
645	1	3031	0
645	1	3032	0
645	1	3033	0
645	1	3034	0
645	1	3035	1
646	1	3036	0
646	1	3037	0
646	1	3038	0
646	1	3039	1
647	1	3040	0
647	1	3041	0
647	1	3042	0
647	1	3043	0
647	1	3044	0
647	1	3045	1
648	1	3046	0
648	1	3047	0
648	1	3048	1
649	1	3049	0
649	1	3050	0
649	1	3051	0
649	1	3052	0
649	1	3053	1
650	1	3054	0
656	1	3089	1
667	1	3134	0
\.


--
-- Data for Name: ciclo_item; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ciclo_item (id_ciclo, id_tipo_jogo, nr_concurso, nr_ausente) FROM stdin;
151	1	730	5
151	1	731	5
151	1	732	5
151	1	733	0
152	1	734	1
152	1	734	4
152	1	734	5
152	1	734	7
152	1	734	11
152	1	734	12
152	1	734	14
152	1	734	16
152	1	734	22
152	1	734	25
152	1	735	1
152	1	735	4
152	1	735	7
152	1	735	16
152	1	736	1
152	1	736	7
152	1	737	1
152	1	738	1
152	1	739	1
152	1	740	0
153	1	741	1
153	1	741	4
153	1	741	6
153	1	741	8
153	1	741	9
153	1	741	15
153	1	741	19
153	1	741	20
153	1	741	22
153	1	741	23
153	1	742	4
153	1	742	22
153	1	743	4
153	1	744	0
154	1	745	2
154	1	745	4
154	1	745	5
154	1	745	10
154	1	745	14
154	1	745	15
154	1	745	18
154	1	745	19
154	1	745	21
154	1	745	23
154	1	746	14
154	1	746	15
154	1	746	23
154	1	747	14
154	1	748	14
154	1	749	0
155	1	750	1
155	1	750	6
155	1	750	8
155	1	750	12
155	1	750	14
155	1	750	16
155	1	750	17
155	1	750	18
155	1	750	22
155	1	750	23
155	1	751	1
155	1	751	18
155	1	752	0
156	1	753	2
156	1	753	9
156	1	753	10
156	1	753	12
156	1	753	15
156	1	753	16
156	1	753	18
156	1	753	19
156	1	753	23
156	1	753	24
156	1	754	2
156	1	754	9
156	1	754	10
156	1	754	12
156	1	755	9
156	1	756	9
156	1	757	0
157	1	758	3
157	1	758	7
157	1	758	8
157	1	758	9
157	1	758	10
157	1	758	13
157	1	758	14
157	1	758	19
157	1	758	21
157	1	758	22
157	1	759	3
157	1	759	13
157	1	759	14
157	1	759	21
157	1	759	22
157	1	760	14
157	1	760	21
157	1	760	22
157	1	761	21
157	1	762	0
158	1	763	5
158	1	763	8
158	1	763	9
158	1	763	10
158	1	763	11
158	1	763	12
158	1	763	15
158	1	763	19
158	1	763	20
158	1	763	23
158	1	764	5
158	1	764	10
158	1	764	15
158	1	764	20
158	1	765	5
158	1	765	15
158	1	766	0
159	1	767	2
159	1	767	6
159	1	767	9
159	1	767	13
159	1	767	14
159	1	767	16
159	1	767	18
159	1	767	20
159	1	767	21
159	1	767	25
159	1	768	2
159	1	768	9
159	1	768	16
159	1	768	18
159	1	768	21
159	1	769	2
159	1	769	9
159	1	769	18
159	1	769	21
159	1	770	2
159	1	771	0
160	1	772	1
160	1	772	3
160	1	772	5
160	1	772	13
160	1	772	14
160	1	772	17
160	1	772	18
160	1	772	19
160	1	772	21
160	1	772	22
160	1	773	1
160	1	773	3
160	1	773	14
160	1	773	19
160	1	773	21
160	1	774	21
160	1	775	21
160	1	776	21
160	1	777	0
161	1	778	1
161	1	778	3
161	1	778	4
161	1	778	8
161	1	778	12
161	1	778	14
161	1	778	17
161	1	778	18
161	1	778	21
161	1	778	23
161	1	779	1
161	1	779	3
161	1	779	18
161	1	780	1
161	1	781	0
162	1	782	1
162	1	782	2
162	1	782	3
162	1	782	4
162	1	782	6
162	1	782	7
162	1	782	22
162	1	782	23
162	1	782	24
162	1	782	25
162	1	783	3
162	1	783	4
162	1	783	23
162	1	783	25
162	1	784	0
163	1	785	3
163	1	785	5
163	1	785	8
163	1	785	9
163	1	785	14
163	1	785	18
163	1	785	20
163	1	785	22
163	1	785	24
163	1	785	25
163	1	786	3
163	1	786	9
163	1	786	14
163	1	786	18
163	1	786	20
163	1	786	22
163	1	787	3
163	1	787	18
163	1	787	22
163	1	788	18
163	1	789	0
164	1	790	1
164	1	790	2
164	1	790	4
164	1	790	5
164	1	790	9
164	1	790	11
164	1	790	14
164	1	790	15
164	1	790	17
164	1	790	21
164	1	791	4
164	1	791	9
164	1	791	15
164	1	791	17
164	1	792	4
164	1	792	15
164	1	792	17
164	1	793	15
164	1	794	0
165	1	795	5
165	1	795	11
165	1	795	13
165	1	795	15
165	1	795	17
165	1	795	18
165	1	795	19
165	1	795	20
165	1	795	23
165	1	795	25
165	1	796	5
165	1	796	13
165	1	796	15
165	1	796	19
165	1	796	23
165	1	796	25
165	1	797	13
165	1	797	23
165	1	798	0
166	1	799	1
166	1	799	2
166	1	799	5
166	1	799	7
166	1	799	9
166	1	799	10
166	1	799	12
166	1	799	17
166	1	799	18
166	1	799	20
166	1	800	1
166	1	800	2
166	1	800	5
166	1	800	17
166	1	800	18
166	1	801	2
166	1	802	2
166	1	803	2
166	1	804	2
166	1	805	0
167	1	806	4
167	1	806	9
167	1	806	11
167	1	806	12
167	1	806	13
167	1	806	17
167	1	806	18
167	1	806	21
167	1	806	22
167	1	806	23
167	1	807	9
167	1	807	12
167	1	807	17
167	1	807	23
167	1	808	9
167	1	808	23
167	1	809	0
168	1	810	2
168	1	810	4
168	1	810	5
168	1	810	8
168	1	810	10
168	1	810	13
168	1	810	14
168	1	810	19
168	1	810	20
168	1	810	25
168	1	811	8
168	1	811	13
168	1	811	25
168	1	812	13
168	1	813	13
168	1	814	0
169	1	815	1
169	1	815	2
169	1	815	3
169	1	815	4
169	1	815	5
169	1	815	9
169	1	815	12
169	1	815	13
169	1	815	16
169	1	815	19
169	1	816	1
169	1	816	4
169	1	817	0
170	1	818	1
170	1	818	2
170	1	818	3
170	1	818	7
170	1	818	9
170	1	818	12
170	1	818	15
170	1	818	17
170	1	818	18
170	1	818	21
170	1	819	1
170	1	819	2
170	1	819	15
170	1	819	17
170	1	820	17
170	1	821	0
171	1	822	1
171	1	822	4
171	1	822	6
171	1	822	7
171	1	822	8
171	1	822	9
171	1	822	10
171	1	822	13
171	1	822	20
171	1	822	25
171	1	823	6
171	1	823	7
171	1	823	8
171	1	823	10
171	1	824	6
171	1	824	8
171	1	824	10
171	1	825	0
172	1	826	1
172	1	826	2
172	1	826	4
172	1	826	7
172	1	826	8
172	1	826	9
172	1	826	10
172	1	826	11
172	1	826	22
172	1	826	25
172	1	827	8
172	1	827	11
172	1	827	25
172	1	828	11
172	1	829	0
173	1	830	2
173	1	830	3
173	1	830	5
173	1	830	7
173	1	830	8
173	1	830	15
173	1	830	18
173	1	830	20
173	1	830	22
173	1	830	25
173	1	831	7
173	1	831	8
173	1	831	15
173	1	831	25
173	1	832	0
174	1	833	1
174	1	833	3
174	1	833	4
174	1	833	8
174	1	833	9
174	1	833	14
174	1	833	15
174	1	833	21
174	1	833	23
174	1	833	24
174	1	834	1
174	1	834	3
174	1	834	15
174	1	834	24
174	1	835	3
174	1	836	3
174	1	837	0
175	1	838	1
175	1	838	3
175	1	838	6
175	1	838	8
175	1	838	12
175	1	838	13
175	1	838	17
175	1	838	19
175	1	838	22
175	1	838	25
175	1	839	1
175	1	839	12
175	1	840	1
175	1	841	0
176	1	842	1
176	1	842	2
176	1	842	6
176	1	842	8
176	1	842	9
176	1	842	12
176	1	842	16
176	1	842	17
176	1	842	23
176	1	842	25
176	1	843	1
176	1	843	2
176	1	843	6
176	1	843	9
176	1	843	23
176	1	843	25
176	1	844	2
176	1	844	6
176	1	844	23
176	1	845	0
177	1	846	2
177	1	846	3
177	1	846	5
177	1	846	7
177	1	846	8
177	1	846	12
177	1	846	16
177	1	846	17
177	1	846	18
177	1	846	22
177	1	847	2
177	1	847	8
177	1	847	12
177	1	847	16
177	1	847	22
177	1	848	12
177	1	848	22
177	1	849	22
177	1	850	0
178	1	851	2
178	1	851	3
178	1	851	8
178	1	851	9
178	1	851	11
178	1	851	12
178	1	851	16
178	1	851	21
178	1	851	23
178	1	851	25
178	1	852	9
178	1	853	0
179	1	854	4
179	1	854	6
179	1	854	7
179	1	854	11
179	1	854	12
179	1	854	16
179	1	854	19
179	1	854	23
179	1	854	24
179	1	854	25
179	1	855	6
179	1	855	7
179	1	855	12
179	1	855	16
179	1	855	19
179	1	856	6
179	1	857	0
180	1	858	2
180	1	858	7
180	1	858	10
180	1	858	13
180	1	858	14
180	1	858	15
180	1	858	16
180	1	858	18
180	1	858	21
180	1	858	24
180	1	859	7
180	1	859	15
180	1	859	16
180	1	859	21
180	1	859	24
180	1	860	21
180	1	861	21
180	1	862	21
180	1	863	21
180	1	864	0
181	1	865	2
181	1	865	8
181	1	865	9
181	1	865	11
181	1	865	12
181	1	865	14
181	1	865	15
181	1	865	16
181	1	865	17
181	1	865	24
181	1	866	12
181	1	866	15
181	1	866	16
181	1	866	17
181	1	867	16
181	1	867	17
181	1	868	0
182	1	869	2
182	1	869	4
182	1	869	5
182	1	869	7
182	1	869	8
182	1	869	13
182	1	869	15
182	1	869	16
182	1	869	17
182	1	869	19
182	1	870	15
182	1	870	19
182	1	871	0
183	1	872	3
183	1	872	8
183	1	872	11
183	1	872	15
183	1	872	16
183	1	872	19
183	1	872	20
183	1	872	21
183	1	872	24
183	1	872	25
183	1	873	16
183	1	873	19
183	1	873	20
183	1	873	21
183	1	873	24
183	1	874	24
183	1	875	0
184	1	876	1
184	1	876	2
184	1	876	4
184	1	876	8
184	1	876	10
184	1	876	11
184	1	876	15
184	1	876	17
184	1	876	19
184	1	876	22
184	1	877	1
184	1	877	2
184	1	877	4
184	1	877	17
184	1	877	22
184	1	878	4
184	1	878	17
184	1	879	17
184	1	880	17
184	1	881	17
184	1	882	0
185	1	883	1
185	1	883	2
185	1	883	4
185	1	883	11
185	1	883	13
185	1	883	14
185	1	883	15
185	1	883	20
185	1	883	23
185	1	883	24
185	1	884	2
185	1	884	11
185	1	884	14
185	1	884	23
185	1	884	24
185	1	885	14
185	1	886	14
185	1	887	14
185	1	888	0
186	1	889	1
186	1	889	3
186	1	889	8
186	1	889	10
186	1	889	14
186	1	889	15
186	1	889	17
186	1	889	20
186	1	889	23
186	1	889	24
186	1	890	10
186	1	890	14
186	1	890	15
186	1	890	20
186	1	891	10
186	1	891	20
186	1	892	0
187	1	893	7
187	1	893	10
187	1	893	12
187	1	893	13
187	1	893	14
187	1	893	17
187	1	893	18
187	1	893	19
187	1	893	21
187	1	893	25
187	1	894	7
187	1	894	10
187	1	894	17
187	1	895	7
187	1	895	10
187	1	896	10
187	1	897	0
188	1	898	2
188	1	898	3
188	1	898	5
188	1	898	7
188	1	898	15
188	1	898	16
188	1	898	17
188	1	898	19
188	1	898	22
188	1	898	23
188	1	899	2
188	1	899	3
188	1	899	5
188	1	899	19
188	1	899	22
188	1	900	3
188	1	900	5
188	1	900	19
188	1	901	3
188	1	901	5
188	1	901	19
188	1	902	19
188	1	903	19
188	1	904	0
189	1	905	2
189	1	905	3
189	1	905	5
189	1	905	7
189	1	905	9
189	1	905	15
189	1	905	18
189	1	905	19
189	1	905	24
189	1	905	25
189	1	906	15
189	1	906	19
189	1	906	25
189	1	907	19
189	1	907	25
189	1	908	19
189	1	909	19
189	1	910	0
190	1	911	4
190	1	911	7
190	1	911	9
190	1	911	10
190	1	911	12
190	1	911	14
190	1	911	16
190	1	911	18
190	1	911	19
190	1	911	20
190	1	912	9
190	1	912	12
190	1	913	9
190	1	914	9
190	1	915	9
190	1	916	9
190	1	917	9
190	1	918	0
191	1	919	6
191	1	919	8
191	1	919	12
191	1	919	15
191	1	919	16
191	1	919	18
191	1	919	20
191	1	919	23
191	1	919	24
191	1	919	25
191	1	920	8
191	1	920	18
191	1	920	24
191	1	920	25
191	1	921	8
191	1	922	0
192	1	923	2
192	1	923	8
192	1	923	9
192	1	923	11
192	1	923	13
192	1	923	16
192	1	923	17
192	1	923	18
192	1	923	21
192	1	923	23
192	1	924	11
192	1	924	13
192	1	924	21
192	1	924	23
192	1	925	11
192	1	925	21
192	1	926	0
193	1	927	1
193	1	927	4
193	1	927	7
193	1	927	8
193	1	927	10
193	1	927	12
193	1	927	15
193	1	927	18
193	1	927	19
193	1	927	24
193	1	928	7
193	1	928	18
193	1	929	0
194	1	930	1
194	1	930	4
194	1	930	7
194	1	930	8
194	1	930	10
194	1	930	13
194	1	930	17
194	1	930	18
194	1	930	19
194	1	930	21
194	1	931	1
194	1	931	4
194	1	931	7
194	1	931	13
194	1	931	17
194	1	931	18
194	1	931	21
194	1	932	7
194	1	932	17
194	1	933	0
195	1	934	1
195	1	934	5
195	1	934	6
195	1	934	7
195	1	934	12
195	1	934	13
195	1	934	15
195	1	934	16
195	1	934	17
195	1	934	18
195	1	935	13
195	1	935	15
195	1	935	16
195	1	935	17
195	1	936	16
195	1	937	0
196	1	938	1
196	1	938	5
196	1	938	8
196	1	938	9
196	1	938	12
196	1	938	14
196	1	938	21
196	1	938	22
196	1	938	23
196	1	938	24
196	1	939	8
196	1	939	12
196	1	939	14
196	1	939	22
196	1	939	23
196	1	939	24
196	1	940	8
196	1	940	12
196	1	940	22
196	1	940	23
196	1	941	12
196	1	941	22
196	1	942	0
197	1	943	1
197	1	943	2
197	1	943	7
197	1	943	8
197	1	943	11
197	1	943	16
197	1	943	19
197	1	943	20
197	1	943	24
197	1	943	25
197	1	944	2
197	1	944	7
197	1	944	20
197	1	945	7
197	1	946	0
198	1	947	4
198	1	947	6
198	1	947	8
198	1	947	13
198	1	947	14
198	1	947	17
198	1	947	19
198	1	947	21
198	1	947	23
198	1	947	25
198	1	948	4
198	1	948	14
198	1	948	23
198	1	948	25
198	1	949	4
198	1	949	25
198	1	950	0
199	1	951	1
199	1	951	2
199	1	951	4
199	1	951	5
199	1	951	6
199	1	951	11
199	1	951	12
199	1	951	16
199	1	951	18
199	1	951	24
199	1	952	2
199	1	952	5
199	1	952	16
199	1	952	24
199	1	953	0
200	1	954	1
200	1	954	2
200	1	954	4
200	1	954	7
200	1	954	9
200	1	954	15
200	1	954	17
200	1	954	19
200	1	954	21
200	1	954	22
200	1	955	15
200	1	955	17
200	1	955	19
200	1	955	22
200	1	956	15
200	1	957	0
201	1	958	2
201	1	958	3
201	1	958	7
201	1	958	8
201	1	958	10
201	1	958	11
201	1	958	15
201	1	958	18
201	1	958	23
201	1	958	25
201	1	959	3
201	1	959	7
201	1	959	8
201	1	959	10
201	1	959	15
201	1	959	18
201	1	960	8
201	1	960	15
201	1	961	8
201	1	962	0
202	1	963	1
202	1	963	2
202	1	963	5
202	1	963	8
202	1	963	12
202	1	963	13
202	1	963	20
202	1	963	21
202	1	963	22
202	1	963	25
202	1	964	5
202	1	964	8
202	1	964	12
202	1	964	13
202	1	964	22
202	1	964	25
202	1	965	5
202	1	965	12
202	1	965	25
202	1	966	0
203	1	967	1
203	1	967	5
203	1	967	7
203	1	967	12
203	1	967	13
203	1	967	14
203	1	967	15
203	1	967	18
203	1	967	19
203	1	967	24
203	1	968	1
203	1	968	12
203	1	968	15
203	1	968	24
203	1	969	15
203	1	970	0
204	1	971	1
204	1	971	2
204	1	971	8
204	1	971	12
204	1	971	13
204	1	971	14
204	1	971	15
204	1	971	16
204	1	971	17
204	1	971	19
204	1	972	2
204	1	972	12
204	1	972	17
204	1	972	19
204	1	973	12
204	1	973	17
204	1	973	19
204	1	974	0
205	1	975	3
205	1	975	5
205	1	975	8
205	1	975	9
205	1	975	15
205	1	975	18
205	1	975	21
205	1	975	22
205	1	975	23
205	1	975	25
205	1	976	5
205	1	976	8
205	1	976	9
205	1	976	15
205	1	976	18
205	1	976	22
205	1	977	5
205	1	977	9
205	1	977	15
205	1	978	0
206	1	979	1
206	1	979	3
206	1	979	4
206	1	979	11
206	1	979	12
206	1	979	13
206	1	979	15
206	1	979	17
206	1	979	18
206	1	979	20
206	1	980	3
206	1	980	4
206	1	980	15
206	1	980	18
206	1	981	15
206	1	982	15
206	1	983	0
207	1	984	1
207	1	984	3
207	1	984	5
207	1	984	6
207	1	984	7
207	1	984	14
207	1	984	16
207	1	984	17
207	1	984	18
207	1	984	19
207	1	985	1
207	1	985	5
207	1	985	16
207	1	985	19
207	1	986	19
207	1	987	0
208	1	988	2
208	1	988	4
208	1	988	6
208	1	988	8
208	1	988	10
208	1	988	14
208	1	988	18
208	1	988	21
208	1	988	22
208	1	988	23
208	1	989	2
208	1	989	21
208	1	990	2
208	1	990	21
208	1	991	0
209	1	992	2
209	1	992	6
209	1	992	12
209	1	992	14
209	1	992	16
209	1	992	18
209	1	992	21
209	1	992	22
209	1	992	23
209	1	992	25
209	1	993	6
209	1	993	16
209	1	993	18
209	1	994	6
209	1	995	6
209	1	996	0
210	1	997	1
210	1	997	3
210	1	997	6
210	1	997	8
210	1	997	11
210	1	997	13
210	1	997	14
210	1	997	20
210	1	997	21
210	1	997	25
210	1	998	6
210	1	998	8
210	1	998	13
210	1	998	25
210	1	999	25
210	1	1000	25
600	1	2828	7
600	1	2828	9
600	1	2828	10
600	1	2828	13
600	1	2828	22
600	1	2828	23
600	1	2828	24
600	1	2829	4
600	1	2829	22
600	1	2829	23
600	1	2829	24
600	1	2830	23
600	1	2830	24
600	1	2831	23
600	1	2831	24
600	1	2832	0
601	1	2833	1
601	1	2833	7
601	1	2833	8
601	1	2833	9
601	1	2833	10
601	1	2833	12
601	1	2833	15
601	1	2833	17
601	1	2833	20
601	1	2833	21
601	1	2834	7
601	1	2834	9
601	1	2834	15
601	1	2835	0
602	1	2836	5
602	1	2836	6
602	1	2836	8
602	1	2836	10
602	1	2836	11
602	1	2836	13
602	1	2836	16
602	1	2836	19
602	1	2836	24
602	1	2836	25
602	1	2837	11
602	1	2837	13
602	1	2837	16
602	1	2838	0
603	1	2839	2
603	1	2839	7
603	1	2839	8
603	1	2839	9
603	1	2839	11
603	1	2839	14
603	1	2839	19
603	1	2839	22
603	1	2839	23
603	1	2839	25
603	1	2840	8
603	1	2840	9
603	1	2840	19
603	1	2840	23
603	1	2841	0
604	1	2842	1
604	1	2842	2
604	1	2842	4
604	1	2842	5
604	1	2842	9
604	1	2842	14
604	1	2842	15
604	1	2842	16
604	1	2842	19
604	1	2842	23
604	1	2843	1
604	1	2843	5
604	1	2843	14
604	1	2843	15
604	1	2843	19
604	1	2844	1
604	1	2844	15
604	1	2844	19
604	1	2845	0
605	1	2846	1
605	1	2846	2
605	1	2846	3
605	1	2846	5
605	1	2846	7
605	1	2846	11
605	1	2846	16
605	1	2846	18
605	1	2846	22
605	1	2846	25
210	1	1001	0
211	1	1002	1
211	1	1002	2
211	1	1002	5
211	1	1002	6
211	1	1002	7
211	1	1002	9
211	1	1002	11
211	1	1002	19
211	1	1002	23
211	1	1002	25
211	1	1003	5
211	1	1003	7
211	1	1003	9
211	1	1003	11
211	1	1004	5
211	1	1004	7
211	1	1004	9
211	1	1004	11
211	1	1005	11
211	1	1006	11
211	1	1007	0
212	1	1008	2
212	1	1008	4
212	1	1008	5
212	1	1008	11
212	1	1008	14
212	1	1008	15
212	1	1008	20
212	1	1008	23
212	1	1008	24
212	1	1008	25
212	1	1009	5
212	1	1009	23
212	1	1009	25
212	1	1010	5
212	1	1010	25
212	1	1011	0
213	1	1012	3
213	1	1012	4
213	1	1012	5
213	1	1012	6
213	1	1012	8
213	1	1012	10
213	1	1012	13
213	1	1012	19
213	1	1012	20
213	1	1012	23
213	1	1013	6
213	1	1013	8
213	1	1014	6
213	1	1015	0
214	1	1016	4
214	1	1016	7
214	1	1016	8
214	1	1016	9
214	1	1016	10
214	1	1016	13
214	1	1016	17
214	1	1016	18
214	1	1016	22
214	1	1016	24
214	1	1017	7
214	1	1017	13
214	1	1017	18
214	1	1017	22
214	1	1017	24
214	1	1018	13
214	1	1019	13
214	1	1020	0
215	1	1021	2
215	1	1021	3
215	1	1021	4
215	1	1021	7
215	1	1021	8
215	1	1021	11
215	1	1021	12
215	1	1021	17
215	1	1021	24
215	1	1021	25
215	1	1022	2
215	1	1022	11
215	1	1022	12
215	1	1022	17
215	1	1023	12
215	1	1023	17
215	1	1024	0
216	1	1025	3
216	1	1025	4
216	1	1025	5
216	1	1025	6
216	1	1025	8
216	1	1025	10
216	1	1025	12
216	1	1025	20
216	1	1025	21
216	1	1025	24
216	1	1026	3
216	1	1026	4
216	1	1026	8
216	1	1026	10
216	1	1027	4
216	1	1028	0
217	1	1029	4
217	1	1029	5
217	1	1029	7
217	1	1029	9
217	1	1029	10
217	1	1029	12
217	1	1029	15
217	1	1029	16
217	1	1029	20
217	1	1029	21
217	1	1030	5
217	1	1030	7
217	1	1030	12
217	1	1030	21
217	1	1031	7
217	1	1031	21
217	1	1032	7
217	1	1032	21
217	1	1033	0
218	1	1034	1
218	1	1034	5
218	1	1034	7
218	1	1034	9
218	1	1034	11
218	1	1034	15
218	1	1034	16
218	1	1034	22
218	1	1034	24
218	1	1034	25
218	1	1035	1
218	1	1035	5
218	1	1035	11
218	1	1035	16
218	1	1035	24
218	1	1036	1
218	1	1036	16
218	1	1037	16
218	1	1038	0
219	1	1039	4
219	1	1039	5
219	1	1039	6
219	1	1039	7
219	1	1039	10
219	1	1039	11
219	1	1039	16
219	1	1039	17
219	1	1039	23
219	1	1039	25
219	1	1040	5
219	1	1040	7
219	1	1040	11
219	1	1040	17
219	1	1041	11
219	1	1042	0
220	1	1043	3
220	1	1043	4
220	1	1043	5
220	1	1043	13
220	1	1043	15
220	1	1043	16
220	1	1043	20
220	1	1043	21
220	1	1043	22
220	1	1043	23
220	1	1044	3
220	1	1044	13
220	1	1044	16
220	1	1044	21
220	1	1044	22
220	1	1045	13
220	1	1046	0
221	1	1047	1
221	1	1047	2
221	1	1047	3
221	1	1047	5
221	1	1047	6
221	1	1047	13
221	1	1047	14
221	1	1047	18
221	1	1047	19
221	1	1047	23
221	1	1048	13
221	1	1048	14
221	1	1048	19
221	1	1048	23
221	1	1049	13
221	1	1050	0
222	1	1051	1
222	1	1051	5
222	1	1051	6
222	1	1051	9
222	1	1051	12
222	1	1051	15
222	1	1051	17
222	1	1051	19
222	1	1051	22
222	1	1051	24
222	1	1052	9
222	1	1052	12
222	1	1052	15
222	1	1052	19
222	1	1052	22
222	1	1053	9
222	1	1053	19
222	1	1054	19
222	1	1055	19
222	1	1056	0
223	1	1057	2
223	1	1057	3
223	1	1057	5
223	1	1057	10
223	1	1057	12
223	1	1057	15
223	1	1057	17
223	1	1057	18
223	1	1057	22
223	1	1057	24
223	1	1058	2
223	1	1058	3
223	1	1058	10
223	1	1058	15
223	1	1059	10
223	1	1060	10
223	1	1061	10
223	1	1062	10
223	1	1063	0
224	1	1064	1
224	1	1064	4
224	1	1064	5
224	1	1064	6
224	1	1064	12
224	1	1064	13
224	1	1064	17
224	1	1064	20
224	1	1064	22
224	1	1064	23
224	1	1065	1
224	1	1065	13
224	1	1065	23
224	1	1066	1
224	1	1066	13
224	1	1067	0
225	1	1068	1
225	1	1068	3
225	1	1068	4
225	1	1068	5
225	1	1068	8
225	1	1068	9
225	1	1068	12
225	1	1068	19
225	1	1068	23
225	1	1068	25
225	1	1069	5
225	1	1069	9
225	1	1069	19
225	1	1070	5
225	1	1071	0
226	1	1072	6
226	1	1072	8
226	1	1072	10
226	1	1072	11
226	1	1072	12
226	1	1072	16
226	1	1072	18
226	1	1072	19
226	1	1072	21
226	1	1072	24
226	1	1073	8
226	1	1073	10
226	1	1073	11
226	1	1073	12
226	1	1073	18
226	1	1074	12
226	1	1074	18
226	1	1075	0
227	1	1076	1
227	1	1076	2
227	1	1076	3
227	1	1076	5
227	1	1076	6
227	1	1076	7
227	1	1076	8
227	1	1076	19
227	1	1076	23
227	1	1076	24
227	1	1077	3
227	1	1077	23
227	1	1078	3
227	1	1079	3
227	1	1080	0
228	1	1081	2
228	1	1081	3
228	1	1081	4
228	1	1081	8
228	1	1081	9
228	1	1081	11
228	1	1081	17
228	1	1081	20
228	1	1081	24
228	1	1081	25
228	1	1082	2
228	1	1082	4
228	1	1082	8
228	1	1082	20
228	1	1082	25
228	1	1083	8
228	1	1083	25
228	1	1084	8
228	1	1085	0
229	1	1086	1
229	1	1086	3
229	1	1086	6
229	1	1086	8
229	1	1086	9
229	1	1086	11
229	1	1086	14
229	1	1086	16
229	1	1086	20
229	1	1086	25
229	1	1087	1
229	1	1087	8
229	1	1087	11
229	1	1087	14
229	1	1087	25
229	1	1088	8
229	1	1088	11
229	1	1088	14
229	1	1088	25
229	1	1089	11
229	1	1089	25
229	1	1090	25
229	1	1091	0
230	1	1092	1
230	1	1092	2
230	1	1092	3
230	1	1092	6
230	1	1092	7
230	1	1092	10
230	1	1092	16
230	1	1092	17
230	1	1092	21
230	1	1092	23
230	1	1093	3
230	1	1093	7
230	1	1093	16
230	1	1093	17
230	1	1094	7
230	1	1094	17
230	1	1095	0
231	1	1096	3
231	1	1096	5
231	1	1096	6
231	1	1096	9
231	1	1096	11
231	1	1096	16
231	1	1096	17
231	1	1096	18
231	1	1096	19
231	1	1096	24
231	1	1097	3
231	1	1097	11
231	1	1097	17
231	1	1098	17
231	1	1099	17
231	1	1100	17
231	1	1101	0
232	1	1102	1
232	1	1102	4
232	1	1102	7
232	1	1102	9
232	1	1102	10
232	1	1102	11
232	1	1102	13
232	1	1102	16
232	1	1102	17
232	1	1102	25
232	1	1103	1
232	1	1103	13
232	1	1103	17
232	1	1104	1
232	1	1104	17
232	1	1105	0
233	1	1106	1
233	1	1106	5
233	1	1106	6
233	1	1106	7
233	1	1106	8
233	1	1106	17
233	1	1106	18
233	1	1106	20
233	1	1106	22
233	1	1106	25
233	1	1107	5
233	1	1107	6
233	1	1107	7
233	1	1107	17
233	1	1107	22
233	1	1107	25
233	1	1108	6
233	1	1109	0
234	1	1110	5
234	1	1110	7
234	1	1110	8
234	1	1110	11
234	1	1110	12
234	1	1110	13
234	1	1110	14
234	1	1110	16
234	1	1110	21
234	1	1110	23
234	1	1111	5
234	1	1111	7
234	1	1111	8
234	1	1111	21
234	1	1112	5
234	1	1112	21
234	1	1113	5
234	1	1113	21
234	1	1114	21
234	1	1115	21
234	1	1116	0
235	1	1117	4
235	1	1117	6
235	1	1117	9
235	1	1117	10
235	1	1117	17
235	1	1117	18
235	1	1117	20
235	1	1117	22
235	1	1117	24
235	1	1117	25
235	1	1118	4
235	1	1118	9
235	1	1118	17
235	1	1118	18
235	1	1118	22
235	1	1119	4
235	1	1119	9
235	1	1119	22
235	1	1120	22
235	1	1121	0
236	1	1122	1
236	1	1122	4
236	1	1122	5
236	1	1122	6
236	1	1122	8
236	1	1122	9
236	1	1122	15
236	1	1122	17
236	1	1122	18
236	1	1122	22
236	1	1123	1
236	1	1123	5
236	1	1123	9
236	1	1123	18
236	1	1124	9
236	1	1124	18
236	1	1125	0
237	1	1126	1
237	1	1126	2
237	1	1126	4
237	1	1126	9
237	1	1126	10
237	1	1126	11
237	1	1126	14
237	1	1126	15
237	1	1126	20
237	1	1126	21
237	1	1127	2
237	1	1127	10
237	1	1127	20
237	1	1127	21
237	1	1128	21
237	1	1129	0
238	1	1130	3
238	1	1130	4
238	1	1130	6
238	1	1130	7
238	1	1130	9
238	1	1130	16
238	1	1130	18
238	1	1130	19
238	1	1130	21
238	1	1130	23
238	1	1131	7
238	1	1131	9
238	1	1131	18
238	1	1131	23
238	1	1132	18
238	1	1133	0
239	1	1134	3
239	1	1134	5
239	1	1134	6
239	1	1134	7
239	1	1134	9
239	1	1134	16
239	1	1134	19
239	1	1134	21
239	1	1134	22
239	1	1134	24
239	1	1135	6
239	1	1135	7
239	1	1135	21
239	1	1135	22
239	1	1136	0
240	1	1137	1
240	1	1137	3
240	1	1137	6
240	1	1137	13
240	1	1137	14
240	1	1137	16
240	1	1137	17
240	1	1137	18
240	1	1137	22
240	1	1137	24
240	1	1138	14
240	1	1138	17
240	1	1138	24
240	1	1139	24
240	1	1140	0
241	1	1141	1
241	1	1141	2
241	1	1141	3
241	1	1141	4
241	1	1141	7
241	1	1141	8
241	1	1141	14
241	1	1141	19
241	1	1141	20
241	1	1141	21
241	1	1142	1
241	1	1142	3
241	1	1142	14
241	1	1142	21
241	1	1143	21
241	1	1144	21
241	1	1145	21
241	1	1146	0
242	1	1147	2
242	1	1147	3
242	1	1147	4
242	1	1147	5
242	1	1147	10
242	1	1147	13
242	1	1147	17
242	1	1147	21
242	1	1147	23
242	1	1147	24
242	1	1148	2
242	1	1148	21
242	1	1148	23
242	1	1149	0
243	1	1150	1
243	1	1150	2
243	1	1150	3
243	1	1150	4
243	1	1150	6
243	1	1150	10
243	1	1150	16
243	1	1150	19
243	1	1150	21
243	1	1150	25
243	1	1151	2
243	1	1151	4
243	1	1151	6
243	1	1151	19
243	1	1152	2
243	1	1152	6
243	1	1153	0
244	1	1154	2
244	1	1154	6
244	1	1154	7
244	1	1154	8
244	1	1154	9
244	1	1154	12
244	1	1154	14
244	1	1154	18
244	1	1154	20
244	1	1154	22
244	1	1155	6
244	1	1155	7
244	1	1155	14
244	1	1155	20
244	1	1156	20
244	1	1157	20
244	1	1158	0
245	1	1159	5
245	1	1159	7
245	1	1159	10
245	1	1159	11
245	1	1159	12
245	1	1159	13
245	1	1159	18
245	1	1159	19
245	1	1159	20
245	1	1159	21
245	1	1160	12
245	1	1160	13
245	1	1160	19
245	1	1160	20
245	1	1161	12
245	1	1161	13
245	1	1161	20
245	1	1162	12
245	1	1163	0
246	1	1164	1
246	1	1164	2
246	1	1164	6
246	1	1164	7
246	1	1164	9
246	1	1164	12
246	1	1164	14
246	1	1164	16
246	1	1164	18
246	1	1164	19
246	1	1165	6
246	1	1165	7
246	1	1165	14
246	1	1165	16
246	1	1166	7
246	1	1166	16
246	1	1167	0
247	1	1168	2
247	1	1168	6
247	1	1168	12
247	1	1168	14
247	1	1168	15
247	1	1168	17
247	1	1168	18
247	1	1168	20
247	1	1168	21
247	1	1168	22
247	1	1169	6
247	1	1169	14
247	1	1169	20
247	1	1170	6
247	1	1170	14
247	1	1171	6
247	1	1172	0
248	1	1173	3
248	1	1173	6
248	1	1173	10
248	1	1173	12
248	1	1173	13
248	1	1173	15
248	1	1173	17
248	1	1173	23
248	1	1173	24
248	1	1173	25
248	1	1174	12
248	1	1174	24
248	1	1174	25
248	1	1175	0
249	1	1176	1
249	1	1176	4
249	1	1176	6
249	1	1176	8
249	1	1176	9
249	1	1176	14
249	1	1176	17
249	1	1176	21
249	1	1176	22
249	1	1176	24
249	1	1177	1
249	1	1177	4
249	1	1177	14
249	1	1177	21
249	1	1177	24
249	1	1178	14
249	1	1179	14
249	1	1180	0
250	1	1181	1
250	1	1181	2
250	1	1181	10
250	1	1181	12
250	1	1181	15
250	1	1181	16
250	1	1181	17
250	1	1181	18
250	1	1181	19
250	1	1181	25
250	1	1182	1
250	1	1182	2
250	1	1182	15
250	1	1182	17
250	1	1183	2
250	1	1183	17
250	1	1184	0
251	1	1185	1
251	1	1185	2
251	1	1185	4
251	1	1185	8
251	1	1185	10
251	1	1185	11
251	1	1185	12
251	1	1185	15
251	1	1185	17
251	1	1185	20
251	1	1186	8
251	1	1186	10
251	1	1186	12
251	1	1186	17
251	1	1187	17
251	1	1188	17
251	1	1189	0
252	1	1190	1
252	1	1190	5
252	1	1190	7
252	1	1190	8
252	1	1190	12
252	1	1190	13
252	1	1190	18
252	1	1190	19
252	1	1190	20
252	1	1190	24
252	1	1191	8
252	1	1191	19
252	1	1191	20
252	1	1192	8
252	1	1193	0
253	1	1194	1
253	1	1194	3
253	1	1194	5
253	1	1194	6
253	1	1194	7
253	1	1194	11
253	1	1194	13
253	1	1194	14
253	1	1194	20
253	1	1194	21
253	1	1195	3
253	1	1195	7
253	1	1195	13
253	1	1195	21
253	1	1196	3
253	1	1196	13
253	1	1196	21
253	1	1197	3
253	1	1197	21
253	1	1198	0
254	1	1199	7
254	1	1199	8
254	1	1199	9
254	1	1199	11
254	1	1199	12
254	1	1199	13
254	1	1199	17
254	1	1199	18
254	1	1199	20
254	1	1199	23
254	1	1200	9
254	1	1200	13
254	1	1200	17
254	1	1200	18
254	1	1200	20
254	1	1200	23
254	1	1201	13
254	1	1201	17
254	1	1202	0
255	1	1203	4
255	1	1203	7
255	1	1203	8
255	1	1203	9
255	1	1203	10
255	1	1203	16
255	1	1203	18
255	1	1203	19
255	1	1203	20
255	1	1203	21
255	1	1204	4
255	1	1204	10
255	1	1204	18
255	1	1205	4
255	1	1205	10
255	1	1206	4
255	1	1207	0
256	1	1208	6
256	1	1208	7
256	1	1208	8
256	1	1208	9
256	1	1208	12
256	1	1208	13
256	1	1208	16
256	1	1208	17
256	1	1208	21
256	1	1208	23
256	1	1209	6
256	1	1209	12
256	1	1209	13
256	1	1209	17
256	1	1209	21
256	1	1209	23
256	1	1210	6
256	1	1210	12
256	1	1210	17
256	1	1210	23
256	1	1211	6
256	1	1212	0
257	1	1213	1
257	1	1213	4
257	1	1213	11
257	1	1213	12
257	1	1213	13
257	1	1213	15
257	1	1213	16
257	1	1213	19
257	1	1213	21
257	1	1213	22
257	1	1214	11
257	1	1214	12
257	1	1214	15
257	1	1214	16
257	1	1214	22
257	1	1215	0
258	1	1216	4
258	1	1216	5
258	1	1216	6
258	1	1216	8
258	1	1216	9
258	1	1216	11
258	1	1216	13
258	1	1216	16
258	1	1216	19
258	1	1216	25
258	1	1217	4
258	1	1217	5
258	1	1217	16
258	1	1218	16
258	1	1219	0
259	1	1220	1
259	1	1220	8
259	1	1220	10
259	1	1220	11
259	1	1220	12
259	1	1220	15
259	1	1220	16
259	1	1220	21
259	1	1220	22
259	1	1220	24
259	1	1221	1
259	1	1221	8
259	1	1221	11
259	1	1221	16
259	1	1222	16
259	1	1223	0
260	1	1224	3
260	1	1224	7
260	1	1224	10
260	1	1224	13
260	1	1224	20
260	1	1224	21
260	1	1224	22
260	1	1224	23
260	1	1224	24
260	1	1224	25
260	1	1225	10
260	1	1225	22
260	1	1226	0
261	1	1227	3
261	1	1227	4
261	1	1227	5
261	1	1227	6
261	1	1227	15
261	1	1227	16
261	1	1227	18
261	1	1227	20
261	1	1227	23
261	1	1227	24
261	1	1228	5
261	1	1228	15
261	1	1228	16
261	1	1228	18
261	1	1229	15
261	1	1229	16
261	1	1229	18
261	1	1230	15
261	1	1230	16
261	1	1231	0
262	1	1232	1
262	1	1232	4
262	1	1232	7
262	1	1232	8
262	1	1232	11
262	1	1232	12
262	1	1232	17
262	1	1232	18
262	1	1232	20
262	1	1232	22
262	1	1233	7
262	1	1233	8
262	1	1233	11
262	1	1233	12
262	1	1233	20
262	1	1234	7
262	1	1234	11
262	1	1234	12
262	1	1235	7
262	1	1236	0
263	1	1237	1
263	1	1237	2
263	1	1237	4
263	1	1237	11
263	1	1237	15
263	1	1237	16
263	1	1237	17
263	1	1237	19
263	1	1237	20
263	1	1237	23
263	1	1238	1
263	1	1238	4
263	1	1238	19
263	1	1238	20
263	1	1238	23
263	1	1239	1
263	1	1239	4
263	1	1239	19
263	1	1239	23
263	1	1240	23
263	1	1241	23
263	1	1242	0
264	1	1243	3
264	1	1243	7
264	1	1243	9
264	1	1243	10
264	1	1243	11
264	1	1243	18
264	1	1243	19
264	1	1243	20
264	1	1243	21
264	1	1243	23
264	1	1244	18
264	1	1244	20
264	1	1245	20
264	1	1246	20
264	1	1247	0
265	1	1248	2
265	1	1248	4
265	1	1248	6
265	1	1248	7
265	1	1248	8
265	1	1248	9
265	1	1248	14
265	1	1248	18
265	1	1248	21
265	1	1248	23
265	1	1249	2
265	1	1249	7
265	1	1249	8
265	1	1249	21
265	1	1249	23
265	1	1250	8
265	1	1250	21
265	1	1250	23
265	1	1251	0
266	1	1252	2
266	1	1252	7
266	1	1252	13
266	1	1252	14
266	1	1252	16
266	1	1252	17
266	1	1252	18
266	1	1252	19
266	1	1252	22
266	1	1252	25
266	1	1253	13
266	1	1253	14
266	1	1253	17
266	1	1253	19
266	1	1254	13
266	1	1254	19
266	1	1255	19
266	1	1256	0
267	1	1257	3
267	1	1257	4
267	1	1257	7
267	1	1257	9
267	1	1257	15
267	1	1257	17
267	1	1257	18
267	1	1257	21
267	1	1257	23
267	1	1257	24
267	1	1258	7
267	1	1258	15
267	1	1258	17
267	1	1258	18
267	1	1258	24
267	1	1259	7
267	1	1259	15
267	1	1259	24
267	1	1260	0
268	1	1261	2
268	1	1261	3
268	1	1261	6
268	1	1261	8
268	1	1261	9
268	1	1261	11
268	1	1261	13
268	1	1261	14
268	1	1261	23
268	1	1261	24
268	1	1262	2
268	1	1262	9
268	1	1262	14
268	1	1263	2
268	1	1263	14
268	1	1264	2
268	1	1265	0
269	1	1266	4
269	1	1266	7
269	1	1266	12
269	1	1266	16
269	1	1266	17
269	1	1266	18
269	1	1266	19
269	1	1266	21
269	1	1266	22
269	1	1266	25
269	1	1267	4
269	1	1267	19
269	1	1267	21
269	1	1268	4
269	1	1268	19
269	1	1269	19
269	1	1270	19
269	1	1271	19
269	1	1272	0
270	1	1273	2
270	1	1273	4
270	1	1273	7
270	1	1273	9
270	1	1273	10
270	1	1273	16
270	1	1273	17
270	1	1273	21
270	1	1273	23
270	1	1273	25
270	1	1274	2
270	1	1274	4
270	1	1274	9
270	1	1274	16
270	1	1274	17
270	1	1274	21
270	1	1274	23
270	1	1275	2
270	1	1275	4
270	1	1275	9
270	1	1275	21
270	1	1276	2
270	1	1276	4
270	1	1276	9
270	1	1277	0
271	1	1278	1
271	1	1278	2
271	1	1278	3
271	1	1278	5
271	1	1278	8
271	1	1278	11
271	1	1278	13
271	1	1278	14
271	1	1278	23
271	1	1278	25
271	1	1279	2
271	1	1279	5
271	1	1279	25
271	1	1280	2
271	1	1281	2
271	1	1282	2
271	1	1283	0
272	1	1284	1
272	1	1284	3
272	1	1284	6
272	1	1284	9
272	1	1284	12
272	1	1284	14
272	1	1284	15
272	1	1284	19
272	1	1284	21
272	1	1284	24
272	1	1285	3
272	1	1285	9
272	1	1285	14
272	1	1285	19
272	1	1285	21
272	1	1286	9
272	1	1286	14
272	1	1287	14
272	1	1288	14
272	1	1289	14
272	1	1290	0
273	1	1291	2
273	1	1291	3
273	1	1291	4
273	1	1291	5
273	1	1291	9
273	1	1291	14
273	1	1291	17
273	1	1291	22
273	1	1291	23
273	1	1291	25
273	1	1292	4
273	1	1292	5
273	1	1292	9
273	1	1293	4
273	1	1293	5
273	1	1294	4
273	1	1295	4
273	1	1296	4
273	1	1297	4
273	1	1298	0
274	1	1299	2
274	1	1299	4
274	1	1299	6
274	1	1299	9
274	1	1299	10
274	1	1299	12
274	1	1299	14
274	1	1299	15
274	1	1299	16
274	1	1299	24
274	1	1300	4
274	1	1300	16
274	1	1301	0
275	1	1302	1
275	1	1302	2
275	1	1302	5
275	1	1302	7
275	1	1302	8
275	1	1302	10
275	1	1302	19
275	1	1302	21
275	1	1302	23
275	1	1302	24
275	1	1303	2
275	1	1303	7
275	1	1303	21
275	1	1303	24
275	1	1304	24
275	1	1305	24
275	1	1306	24
275	1	1307	24
275	1	1308	24
275	1	1309	0
276	1	1310	6
276	1	1310	9
276	1	1310	12
276	1	1310	13
276	1	1310	14
276	1	1310	16
276	1	1310	20
276	1	1310	22
276	1	1310	24
276	1	1310	25
276	1	1311	9
276	1	1311	13
276	1	1311	16
276	1	1311	22
276	1	1311	24
276	1	1312	16
276	1	1312	22
276	1	1313	0
277	1	1314	1
277	1	1314	2
277	1	1314	4
277	1	1314	6
277	1	1314	7
277	1	1314	12
277	1	1314	13
277	1	1314	17
277	1	1314	20
277	1	1314	23
277	1	1315	6
277	1	1315	7
277	1	1315	13
277	1	1315	17
277	1	1315	20
277	1	1316	7
277	1	1316	13
277	1	1317	13
277	1	1318	0
278	1	1319	1
278	1	1319	2
278	1	1319	4
278	1	1319	7
278	1	1319	12
278	1	1319	16
278	1	1319	18
278	1	1319	20
278	1	1319	21
278	1	1319	24
278	1	1320	1
278	1	1320	7
278	1	1320	18
278	1	1320	20
278	1	1320	24
278	1	1321	1
278	1	1322	0
279	1	1323	2
279	1	1323	3
279	1	1323	7
279	1	1323	8
279	1	1323	12
279	1	1323	15
279	1	1323	16
279	1	1323	18
279	1	1323	24
279	1	1323	25
279	1	1324	2
279	1	1324	3
279	1	1324	12
279	1	1324	15
279	1	1324	16
279	1	1325	12
279	1	1326	12
279	1	1327	12
279	1	1328	12
279	1	1329	12
279	1	1330	0
280	1	1331	4
280	1	1331	8
280	1	1331	9
280	1	1331	12
280	1	1331	13
280	1	1331	17
280	1	1331	19
280	1	1331	20
280	1	1331	21
280	1	1331	22
280	1	1332	9
280	1	1332	17
280	1	1332	19
280	1	1332	22
280	1	1333	19
280	1	1334	0
281	1	1335	2
281	1	1335	5
281	1	1335	8
281	1	1335	12
281	1	1335	14
281	1	1335	15
281	1	1335	19
281	1	1335	20
281	1	1335	21
281	1	1335	22
281	1	1336	2
281	1	1336	5
281	1	1336	21
281	1	1337	2
281	1	1338	0
282	1	1339	1
282	1	1339	9
282	1	1339	10
282	1	1339	12
282	1	1339	15
282	1	1339	17
282	1	1339	18
282	1	1339	19
282	1	1339	22
282	1	1339	25
282	1	1340	15
282	1	1340	25
282	1	1341	25
282	1	1342	0
283	1	1343	1
283	1	1343	3
283	1	1343	6
283	1	1343	7
283	1	1343	8
283	1	1343	12
283	1	1343	18
283	1	1343	20
283	1	1343	22
283	1	1343	25
283	1	1344	1
283	1	1344	3
283	1	1344	20
283	1	1344	22
283	1	1345	20
283	1	1346	0
284	1	1347	2
284	1	1347	4
284	1	1347	9
284	1	1347	11
284	1	1347	15
284	1	1347	16
284	1	1347	19
284	1	1347	21
284	1	1347	22
284	1	1347	25
284	1	1348	4
284	1	1348	11
284	1	1348	16
284	1	1348	19
284	1	1349	11
284	1	1350	0
285	1	1351	1
285	1	1351	3
285	1	1351	5
285	1	1351	8
285	1	1351	9
285	1	1351	12
285	1	1351	14
285	1	1351	15
285	1	1351	16
285	1	1351	18
285	1	1352	1
285	1	1352	3
285	1	1352	5
285	1	1352	9
285	1	1352	18
285	1	1353	1
285	1	1354	0
286	1	1355	5
286	1	1355	9
286	1	1355	10
286	1	1355	12
286	1	1355	13
286	1	1355	14
286	1	1355	17
286	1	1355	19
286	1	1355	23
286	1	1355	25
286	1	1356	5
286	1	1356	23
286	1	1356	25
286	1	1357	5
286	1	1357	25
286	1	1358	5
286	1	1358	25
286	1	1359	25
286	1	1360	25
286	1	1361	0
287	1	1362	2
287	1	1362	5
287	1	1362	7
287	1	1362	8
287	1	1362	14
287	1	1362	15
287	1	1362	17
287	1	1362	18
287	1	1362	19
287	1	1362	20
287	1	1363	2
287	1	1363	8
287	1	1363	18
287	1	1364	2
287	1	1364	8
287	1	1365	8
287	1	1366	0
288	1	1367	1
288	1	1367	8
288	1	1367	10
288	1	1367	11
288	1	1367	12
288	1	1367	13
288	1	1367	19
288	1	1367	21
288	1	1367	22
288	1	1367	25
288	1	1368	1
288	1	1368	13
288	1	1368	21
288	1	1369	1
288	1	1370	1
288	1	1371	1
288	1	1372	0
289	1	1373	9
289	1	1373	10
289	1	1373	11
289	1	1373	13
289	1	1373	14
289	1	1373	15
289	1	1373	16
289	1	1373	19
289	1	1373	22
289	1	1373	25
289	1	1374	11
289	1	1374	13
289	1	1374	22
289	1	1375	13
289	1	1376	0
290	1	1377	2
290	1	1377	3
290	1	1377	4
290	1	1377	7
290	1	1377	11
290	1	1377	14
290	1	1377	16
290	1	1377	18
290	1	1377	23
290	1	1377	24
290	1	1378	4
290	1	1378	7
290	1	1378	11
290	1	1378	14
290	1	1378	16
290	1	1378	18
290	1	1379	11
290	1	1379	16
290	1	1380	0
291	1	1381	2
291	1	1381	3
291	1	1381	5
291	1	1381	7
291	1	1381	11
291	1	1381	15
291	1	1381	20
291	1	1381	22
291	1	1381	23
291	1	1381	24
291	1	1382	2
291	1	1382	3
291	1	1382	5
291	1	1382	7
291	1	1382	11
291	1	1382	23
291	1	1383	3
291	1	1383	5
291	1	1383	11
291	1	1383	23
291	1	1384	5
291	1	1384	23
291	1	1385	0
292	1	1386	5
292	1	1386	6
292	1	1386	8
292	1	1386	10
292	1	1386	11
292	1	1386	12
292	1	1386	14
292	1	1386	15
292	1	1386	20
292	1	1386	23
292	1	1387	8
292	1	1387	10
292	1	1387	20
292	1	1387	23
292	1	1388	0
293	1	1389	3
293	1	1389	7
293	1	1389	9
293	1	1389	11
293	1	1389	13
293	1	1389	19
293	1	1389	22
293	1	1389	23
293	1	1389	24
293	1	1389	25
293	1	1390	9
293	1	1390	19
293	1	1390	22
293	1	1390	24
293	1	1390	25
293	1	1391	9
293	1	1391	22
293	1	1392	0
294	1	1393	1
294	1	1393	2
294	1	1393	6
294	1	1393	8
294	1	1393	15
294	1	1393	16
294	1	1393	19
294	1	1393	21
294	1	1393	24
294	1	1393	25
294	1	1394	1
294	1	1394	2
294	1	1394	8
294	1	1394	24
294	1	1394	25
294	1	1395	1
294	1	1395	2
294	1	1395	24
294	1	1396	1
294	1	1396	2
294	1	1397	2
294	1	1398	2
294	1	1399	2
294	1	1400	0
295	1	1401	2
295	1	1401	9
295	1	1401	10
295	1	1401	11
295	1	1401	12
295	1	1401	13
295	1	1401	16
295	1	1401	17
295	1	1401	20
295	1	1401	23
295	1	1402	10
295	1	1402	13
295	1	1402	17
295	1	1403	0
296	1	1404	5
296	1	1404	6
296	1	1404	7
296	1	1404	9
296	1	1404	12
296	1	1404	14
296	1	1404	17
296	1	1404	20
296	1	1404	23
296	1	1404	24
296	1	1405	5
296	1	1405	6
296	1	1405	12
296	1	1405	17
296	1	1406	12
296	1	1406	17
296	1	1407	17
296	1	1408	17
296	1	1409	0
297	1	1410	1
297	1	1410	8
297	1	1410	11
297	1	1410	12
297	1	1410	13
297	1	1410	18
297	1	1410	19
297	1	1410	22
297	1	1410	24
297	1	1410	25
297	1	1411	11
297	1	1411	18
297	1	1411	19
297	1	1411	22
297	1	1411	24
297	1	1411	25
297	1	1412	0
298	1	1413	1
298	1	1413	11
298	1	1413	12
298	1	1413	14
298	1	1413	15
298	1	1413	19
298	1	1413	20
298	1	1413	22
298	1	1413	23
298	1	1413	24
298	1	1414	1
298	1	1414	12
298	1	1414	15
298	1	1414	19
298	1	1414	22
298	1	1414	24
298	1	1415	1
298	1	1416	1
298	1	1417	0
299	1	1418	1
299	1	1418	3
299	1	1418	5
299	1	1418	7
299	1	1418	8
299	1	1418	12
299	1	1418	16
299	1	1418	19
299	1	1418	24
299	1	1418	25
299	1	1419	1
299	1	1419	5
299	1	1419	8
299	1	1419	25
299	1	1420	5
299	1	1421	0
300	1	1422	2
300	1	1422	3
300	1	1422	6
300	1	1422	8
300	1	1422	9
300	1	1422	12
300	1	1422	18
300	1	1422	20
300	1	1422	21
300	1	1422	25
300	1	1423	3
300	1	1423	6
300	1	1423	9
300	1	1423	18
300	1	1423	20
300	1	1423	21
300	1	1423	25
300	1	1424	3
300	1	1425	0
301	1	1426	1
301	1	1426	5
301	1	1426	6
301	1	1426	9
301	1	1426	11
301	1	1426	13
301	1	1426	17
301	1	1426	19
301	1	1426	20
301	1	1426	21
301	1	1427	5
301	1	1427	6
301	1	1427	9
301	1	1427	13
301	1	1427	21
301	1	1428	0
302	1	1429	1
302	1	1429	2
302	1	1429	3
302	1	1429	4
302	1	1429	6
302	1	1429	11
302	1	1429	17
302	1	1429	22
302	1	1429	23
302	1	1429	24
302	1	1430	2
302	1	1430	6
302	1	1430	11
302	1	1430	17
302	1	1430	24
302	1	1431	6
302	1	1431	11
302	1	1431	24
302	1	1432	6
302	1	1433	0
303	1	1434	1
303	1	1434	2
303	1	1434	8
303	1	1434	11
303	1	1434	14
303	1	1434	16
303	1	1434	17
303	1	1434	20
303	1	1434	21
303	1	1434	25
303	1	1435	8
303	1	1435	11
303	1	1435	14
303	1	1435	25
303	1	1436	14
303	1	1436	25
303	1	1437	0
304	1	1438	2
304	1	1438	3
304	1	1438	5
304	1	1438	6
304	1	1438	13
304	1	1438	16
304	1	1438	18
304	1	1438	19
304	1	1438	23
304	1	1438	25
304	1	1439	6
304	1	1439	23
304	1	1439	25
304	1	1440	6
304	1	1440	23
304	1	1441	0
305	1	1442	5
305	1	1442	6
305	1	1442	8
305	1	1442	10
305	1	1442	14
305	1	1442	18
305	1	1442	22
305	1	1442	23
305	1	1442	24
305	1	1442	25
305	1	1443	6
305	1	1443	18
305	1	1443	22
305	1	1443	23
305	1	1443	25
305	1	1444	22
305	1	1444	23
305	1	1444	25
305	1	1445	0
306	1	1446	2
306	1	1446	3
306	1	1446	5
306	1	1446	9
306	1	1446	10
306	1	1446	11
306	1	1446	14
306	1	1446	15
306	1	1446	18
306	1	1446	19
306	1	1447	2
306	1	1447	9
306	1	1447	10
306	1	1447	14
306	1	1447	15
306	1	1448	2
306	1	1448	9
306	1	1448	10
306	1	1448	14
306	1	1448	15
306	1	1449	2
306	1	1449	10
306	1	1449	14
306	1	1450	0
307	1	1451	4
307	1	1451	6
307	1	1451	7
307	1	1451	8
307	1	1451	9
307	1	1451	11
307	1	1451	16
307	1	1451	17
307	1	1451	18
307	1	1451	22
307	1	1452	4
307	1	1452	6
307	1	1452	9
307	1	1452	16
307	1	1452	18
307	1	1452	22
307	1	1453	4
307	1	1453	6
307	1	1453	18
307	1	1453	22
307	1	1454	6
307	1	1455	6
307	1	1456	0
308	1	1457	5
308	1	1457	6
308	1	1457	12
308	1	1457	16
308	1	1457	17
308	1	1457	19
308	1	1457	20
308	1	1457	21
308	1	1457	22
308	1	1457	25
308	1	1458	6
308	1	1458	12
308	1	1458	16
308	1	1458	21
308	1	1458	25
308	1	1459	21
308	1	1460	0
309	1	1461	1
309	1	1461	3
309	1	1461	7
309	1	1461	8
309	1	1461	12
309	1	1461	13
309	1	1461	14
309	1	1461	16
309	1	1461	20
309	1	1461	22
309	1	1462	8
309	1	1462	22
309	1	1463	8
309	1	1464	8
309	1	1465	0
310	1	1466	1
310	1	1466	5
310	1	1466	7
310	1	1466	8
310	1	1466	9
310	1	1466	13
310	1	1466	15
310	1	1466	16
310	1	1466	17
310	1	1466	18
310	1	1467	7
310	1	1467	8
310	1	1467	13
310	1	1467	15
310	1	1467	16
310	1	1467	17
310	1	1467	18
310	1	1468	7
310	1	1468	15
310	1	1468	16
310	1	1468	17
310	1	1469	15
310	1	1470	0
311	1	1471	3
311	1	1471	5
311	1	1471	9
311	1	1471	12
311	1	1471	14
311	1	1471	16
311	1	1471	17
311	1	1471	19
311	1	1471	23
311	1	1471	25
311	1	1472	9
311	1	1472	16
311	1	1472	17
311	1	1472	19
311	1	1472	25
311	1	1473	17
311	1	1473	19
311	1	1474	17
311	1	1475	17
311	1	1476	17
311	1	1477	0
312	1	1478	1
312	1	1478	3
312	1	1478	4
312	1	1478	8
312	1	1478	9
312	1	1478	13
312	1	1478	14
312	1	1478	20
312	1	1478	22
312	1	1478	23
312	1	1479	1
312	1	1479	4
312	1	1479	8
312	1	1480	4
312	1	1480	8
312	1	1481	4
312	1	1482	0
313	1	1483	1
313	1	1483	2
313	1	1483	8
313	1	1483	10
313	1	1483	12
313	1	1483	16
313	1	1483	18
313	1	1483	19
313	1	1483	24
313	1	1483	25
313	1	1484	8
313	1	1484	16
313	1	1484	24
313	1	1485	16
313	1	1486	16
313	1	1487	0
314	1	1488	2
314	1	1488	3
314	1	1488	7
314	1	1488	8
314	1	1488	9
314	1	1488	14
314	1	1488	15
314	1	1488	17
314	1	1488	18
314	1	1488	22
314	1	1489	3
314	1	1489	17
314	1	1489	18
314	1	1490	17
314	1	1491	17
314	1	1492	0
315	1	1493	1
315	1	1493	3
315	1	1493	4
315	1	1493	6
315	1	1493	7
315	1	1493	9
315	1	1493	12
315	1	1493	17
315	1	1493	18
315	1	1493	22
315	1	1494	6
315	1	1494	7
315	1	1494	18
315	1	1495	6
315	1	1495	7
315	1	1496	0
316	1	1497	3
316	1	1497	4
316	1	1497	6
316	1	1497	8
316	1	1497	9
316	1	1497	10
316	1	1497	20
316	1	1497	21
316	1	1497	24
316	1	1497	25
316	1	1498	3
316	1	1498	6
316	1	1498	9
316	1	1498	20
316	1	1499	6
316	1	1499	9
316	1	1499	20
316	1	1500	6
316	1	1500	9
316	1	1501	0
317	1	1502	6
317	1	1502	8
317	1	1502	9
317	1	1502	10
317	1	1502	14
317	1	1502	16
317	1	1502	19
317	1	1502	21
317	1	1502	23
317	1	1502	25
317	1	1503	6
317	1	1503	8
317	1	1503	9
317	1	1503	10
317	1	1503	14
317	1	1503	19
317	1	1504	6
317	1	1504	9
317	1	1504	10
317	1	1505	9
317	1	1505	10
317	1	1506	0
318	1	1507	6
318	1	1507	7
318	1	1507	9
318	1	1507	12
318	1	1507	15
318	1	1507	16
318	1	1507	18
318	1	1507	20
318	1	1507	22
318	1	1507	25
318	1	1508	6
318	1	1508	15
318	1	1508	16
318	1	1508	18
318	1	1508	20
318	1	1508	25
318	1	1509	16
318	1	1509	20
318	1	1509	25
318	1	1510	16
318	1	1510	20
318	1	1510	25
318	1	1511	16
318	1	1511	25
318	1	1512	25
318	1	1513	25
318	1	1514	25
318	1	1515	25
318	1	1516	25
318	1	1517	0
319	1	1518	1
319	1	1518	6
319	1	1518	9
319	1	1518	10
319	1	1518	13
319	1	1518	15
319	1	1518	18
319	1	1518	19
319	1	1518	21
319	1	1518	23
319	1	1519	9
319	1	1519	10
319	1	1519	15
319	1	1519	19
319	1	1520	15
319	1	1521	0
320	1	1522	2
320	1	1522	3
320	1	1522	4
320	1	1522	5
320	1	1522	6
320	1	1522	7
320	1	1522	12
320	1	1522	17
320	1	1522	22
320	1	1522	25
320	1	1523	2
320	1	1523	4
320	1	1523	17
320	1	1523	22
320	1	1524	2
320	1	1524	4
320	1	1524	17
320	1	1525	17
320	1	1526	0
321	1	1527	4
321	1	1527	8
321	1	1527	11
321	1	1527	12
321	1	1527	13
321	1	1527	16
321	1	1527	17
321	1	1527	18
321	1	1527	19
321	1	1527	23
321	1	1528	11
321	1	1528	12
321	1	1528	13
321	1	1528	16
321	1	1528	19
321	1	1529	12
321	1	1530	0
322	1	1531	5
322	1	1531	6
322	1	1531	9
322	1	1531	12
322	1	1531	16
322	1	1531	17
322	1	1531	18
322	1	1531	20
322	1	1531	21
322	1	1531	25
322	1	1532	5
322	1	1532	6
322	1	1532	16
322	1	1532	21
322	1	1533	5
322	1	1534	0
323	1	1535	1
323	1	1535	2
323	1	1535	6
323	1	1535	9
323	1	1535	10
323	1	1535	11
323	1	1535	14
323	1	1535	16
323	1	1535	19
323	1	1535	20
323	1	1536	2
323	1	1536	14
323	1	1536	16
323	1	1537	16
323	1	1538	16
323	1	1539	0
324	1	1540	4
324	1	1540	5
324	1	1540	6
324	1	1540	8
324	1	1540	13
324	1	1540	18
324	1	1540	20
324	1	1540	21
324	1	1540	24
324	1	1540	25
324	1	1541	6
324	1	1541	8
324	1	1541	24
324	1	1542	6
324	1	1543	0
325	1	1544	3
325	1	1544	5
325	1	1544	6
325	1	1544	10
325	1	1544	13
325	1	1544	15
325	1	1544	18
325	1	1544	19
325	1	1544	20
325	1	1544	25
325	1	1545	6
325	1	1545	13
325	1	1545	18
325	1	1545	19
325	1	1546	13
325	1	1547	0
326	1	1548	1
326	1	1548	5
326	1	1548	6
326	1	1548	7
326	1	1548	8
326	1	1548	13
326	1	1548	16
326	1	1548	19
326	1	1548	24
326	1	1548	25
326	1	1549	6
326	1	1549	16
326	1	1549	19
326	1	1550	6
326	1	1550	19
326	1	1551	6
326	1	1552	6
326	1	1553	6
326	1	1554	6
326	1	1555	0
327	1	1556	4
327	1	1556	7
327	1	1556	9
327	1	1556	10
327	1	1556	11
327	1	1556	13
327	1	1556	14
327	1	1556	18
327	1	1556	20
327	1	1556	24
327	1	1557	7
327	1	1557	10
327	1	1557	11
327	1	1557	13
327	1	1557	14
327	1	1558	7
327	1	1558	10
327	1	1558	13
327	1	1559	13
327	1	1560	13
327	1	1561	0
328	1	1562	10
328	1	1562	13
328	1	1562	15
328	1	1562	19
328	1	1562	20
328	1	1562	21
328	1	1562	22
328	1	1562	23
328	1	1562	24
328	1	1562	25
328	1	1563	15
328	1	1563	19
328	1	1563	24
328	1	1563	25
328	1	1564	15
328	1	1564	25
328	1	1565	0
329	1	1566	3
329	1	1566	6
329	1	1566	10
329	1	1566	11
329	1	1566	12
329	1	1566	17
329	1	1566	18
329	1	1566	20
329	1	1566	21
329	1	1566	22
329	1	1567	6
329	1	1567	20
329	1	1567	22
329	1	1568	20
329	1	1569	0
330	1	1570	2
330	1	1570	4
330	1	1570	5
330	1	1570	6
330	1	1570	10
330	1	1570	12
330	1	1570	14
330	1	1570	15
330	1	1570	17
330	1	1570	22
330	1	1571	2
330	1	1571	10
330	1	1571	15
330	1	1571	22
330	1	1572	15
330	1	1573	0
331	1	1574	4
331	1	1574	8
331	1	1574	9
331	1	1574	13
331	1	1574	16
331	1	1574	19
331	1	1574	20
331	1	1574	23
331	1	1574	24
331	1	1574	25
331	1	1575	4
331	1	1575	8
331	1	1575	13
331	1	1575	19
331	1	1575	20
331	1	1575	24
331	1	1576	4
331	1	1576	13
331	1	1576	19
331	1	1576	24
331	1	1577	4
331	1	1578	0
332	1	1579	3
332	1	1579	5
332	1	1579	8
332	1	1579	9
332	1	1579	11
332	1	1579	17
332	1	1579	19
332	1	1579	20
332	1	1579	24
332	1	1579	25
332	1	1580	5
332	1	1580	8
332	1	1580	9
332	1	1580	17
332	1	1580	19
332	1	1580	24
332	1	1581	9
332	1	1581	17
332	1	1581	19
332	1	1582	9
332	1	1583	0
333	1	1584	4
333	1	1584	7
333	1	1584	8
333	1	1584	9
333	1	1584	10
333	1	1584	13
333	1	1584	18
333	1	1584	21
333	1	1584	22
333	1	1584	23
333	1	1585	8
333	1	1585	10
333	1	1585	13
333	1	1585	22
333	1	1586	8
333	1	1587	0
334	1	1588	2
334	1	1588	6
334	1	1588	8
334	1	1588	12
334	1	1588	13
334	1	1588	16
334	1	1588	18
334	1	1588	19
334	1	1588	24
334	1	1588	25
334	1	1589	8
334	1	1589	16
334	1	1589	19
334	1	1590	19
334	1	1591	0
335	1	1592	7
335	1	1592	8
335	1	1592	10
335	1	1592	11
335	1	1592	13
335	1	1592	17
335	1	1592	18
335	1	1592	21
335	1	1592	23
335	1	1592	24
335	1	1593	18
335	1	1593	21
335	1	1593	23
335	1	1594	18
335	1	1594	23
335	1	1595	23
335	1	1596	0
336	1	1597	3
336	1	1597	4
336	1	1597	10
336	1	1597	11
336	1	1597	12
336	1	1597	14
336	1	1597	15
336	1	1597	16
336	1	1597	23
336	1	1597	25
336	1	1598	3
336	1	1598	4
336	1	1598	11
336	1	1598	14
336	1	1598	23
336	1	1598	25
336	1	1599	11
336	1	1600	11
336	1	1601	0
337	1	1602	2
337	1	1602	5
337	1	1602	6
337	1	1602	7
337	1	1602	12
337	1	1602	16
337	1	1602	18
337	1	1602	20
337	1	1602	22
337	1	1602	25
337	1	1603	5
337	1	1603	6
337	1	1603	12
337	1	1603	18
337	1	1603	22
337	1	1603	25
337	1	1604	18
337	1	1604	25
337	1	1605	0
338	1	1606	2
338	1	1606	4
338	1	1606	6
338	1	1606	12
338	1	1606	13
338	1	1606	16
338	1	1606	17
338	1	1606	18
338	1	1606	21
338	1	1606	24
338	1	1607	4
338	1	1607	16
338	1	1607	21
338	1	1608	4
338	1	1608	16
338	1	1609	4
338	1	1609	16
338	1	1610	4
338	1	1611	0
339	1	1612	1
339	1	1612	6
339	1	1612	8
339	1	1612	9
339	1	1612	10
339	1	1612	13
339	1	1612	16
339	1	1612	17
339	1	1612	19
339	1	1612	20
339	1	1613	20
339	1	1614	20
339	1	1615	0
340	1	1616	3
340	1	1616	6
340	1	1616	7
340	1	1616	9
340	1	1616	12
340	1	1616	15
340	1	1616	19
340	1	1616	20
340	1	1616	21
340	1	1616	25
340	1	1617	3
340	1	1617	19
340	1	1617	21
340	1	1618	21
340	1	1619	0
341	1	1620	3
341	1	1620	5
341	1	1620	6
341	1	1620	8
341	1	1620	15
341	1	1620	16
341	1	1620	17
341	1	1620	19
341	1	1620	22
341	1	1620	23
341	1	1621	5
341	1	1621	15
341	1	1621	16
341	1	1621	17
341	1	1622	5
341	1	1622	15
341	1	1623	5
341	1	1623	15
341	1	1624	5
341	1	1625	5
341	1	1626	5
341	1	1627	5
341	1	1628	5
341	1	1629	0
342	1	1630	1
342	1	1630	2
342	1	1630	4
342	1	1630	6
342	1	1630	11
342	1	1630	16
342	1	1630	18
342	1	1630	19
342	1	1630	21
342	1	1630	24
342	1	1631	1
342	1	1631	6
342	1	1631	16
342	1	1631	21
342	1	1631	24
342	1	1632	1
342	1	1632	6
342	1	1633	0
343	1	1634	1
343	1	1634	2
343	1	1634	8
343	1	1634	11
343	1	1634	12
343	1	1634	16
343	1	1634	17
343	1	1634	18
343	1	1634	20
343	1	1634	23
343	1	1635	2
343	1	1635	11
343	1	1635	18
343	1	1635	20
343	1	1636	11
343	1	1637	0
344	1	1638	2
344	1	1638	3
344	1	1638	4
344	1	1638	5
344	1	1638	6
344	1	1638	9
344	1	1638	13
344	1	1638	17
344	1	1638	18
344	1	1638	21
344	1	1639	2
344	1	1639	4
344	1	1639	13
344	1	1639	17
344	1	1639	18
344	1	1639	21
344	1	1640	13
344	1	1640	18
344	1	1641	13
344	1	1641	18
344	1	1642	0
345	1	1643	6
345	1	1643	8
345	1	1643	11
345	1	1643	13
345	1	1643	15
345	1	1643	17
345	1	1643	18
345	1	1643	20
345	1	1643	21
345	1	1643	24
345	1	1644	17
345	1	1644	20
345	1	1644	21
345	1	1645	17
345	1	1646	0
346	1	1647	3
346	1	1647	5
346	1	1647	6
346	1	1647	11
346	1	1647	13
346	1	1647	16
346	1	1647	17
346	1	1647	18
346	1	1647	21
346	1	1647	23
346	1	1648	3
346	1	1648	5
346	1	1648	6
346	1	1648	18
346	1	1649	3
346	1	1649	6
346	1	1650	6
346	1	1651	0
347	1	1652	1
347	1	1652	8
347	1	1652	9
347	1	1652	12
347	1	1652	13
347	1	1652	15
347	1	1652	19
347	1	1652	20
347	1	1652	22
347	1	1652	23
347	1	1653	1
347	1	1653	8
347	1	1653	9
347	1	1653	13
347	1	1653	19
347	1	1654	8
347	1	1654	9
347	1	1655	8
347	1	1655	9
347	1	1656	8
347	1	1656	9
347	1	1657	0
348	1	1658	1
348	1	1658	3
348	1	1658	9
348	1	1658	10
348	1	1658	11
348	1	1658	14
348	1	1658	21
348	1	1658	22
348	1	1658	24
348	1	1658	25
348	1	1659	1
348	1	1659	3
348	1	1659	11
348	1	1659	24
348	1	1660	0
349	1	1661	1
349	1	1661	4
349	1	1661	8
349	1	1661	9
349	1	1661	15
349	1	1661	16
349	1	1661	19
349	1	1661	20
349	1	1661	24
349	1	1661	25
349	1	1662	4
349	1	1662	9
349	1	1662	15
349	1	1662	16
349	1	1662	19
349	1	1662	24
349	1	1663	4
349	1	1663	15
349	1	1663	19
349	1	1663	24
349	1	1664	19
349	1	1665	19
349	1	1666	19
349	1	1667	19
349	1	1668	19
349	1	1669	19
349	1	1670	19
349	1	1671	0
350	1	1672	1
350	1	1672	4
350	1	1672	7
350	1	1672	10
350	1	1672	12
350	1	1672	13
350	1	1672	14
350	1	1672	15
350	1	1672	16
350	1	1672	19
350	1	1673	10
350	1	1673	13
350	1	1673	14
350	1	1673	16
350	1	1674	13
350	1	1674	14
350	1	1674	16
350	1	1675	13
350	1	1675	16
350	1	1676	0
351	1	1677	2
351	1	1677	3
351	1	1677	7
351	1	1677	8
351	1	1677	10
351	1	1677	13
351	1	1677	21
351	1	1677	23
351	1	1677	24
351	1	1677	25
351	1	1678	2
351	1	1678	7
351	1	1678	10
351	1	1678	13
351	1	1678	21
351	1	1678	25
351	1	1679	2
351	1	1679	13
351	1	1679	25
351	1	1680	0
352	1	1681	4
352	1	1681	5
352	1	1681	6
352	1	1681	9
352	1	1681	13
352	1	1681	14
352	1	1681	18
352	1	1681	19
352	1	1681	21
352	1	1681	24
352	1	1682	14
352	1	1682	24
352	1	1683	14
352	1	1684	0
353	1	1685	4
353	1	1685	8
353	1	1685	9
353	1	1685	10
353	1	1685	13
353	1	1685	15
353	1	1685	18
353	1	1685	20
353	1	1685	23
353	1	1685	25
353	1	1686	8
353	1	1686	25
353	1	1687	8
353	1	1687	25
353	1	1688	0
354	1	1689	3
354	1	1689	4
354	1	1689	5
354	1	1689	8
354	1	1689	12
354	1	1689	15
354	1	1689	20
354	1	1689	21
354	1	1689	24
354	1	1689	25
354	1	1690	3
354	1	1690	12
354	1	1690	21
354	1	1690	24
354	1	1691	21
354	1	1691	24
354	1	1692	21
354	1	1693	0
355	1	1694	6
355	1	1694	7
355	1	1694	8
355	1	1694	10
355	1	1694	14
355	1	1694	15
355	1	1694	16
355	1	1694	21
355	1	1694	22
355	1	1694	25
355	1	1695	6
355	1	1695	7
355	1	1695	8
355	1	1695	10
355	1	1695	15
355	1	1695	16
355	1	1696	6
355	1	1696	15
355	1	1697	15
355	1	1698	15
355	1	1699	0
356	1	1700	4
356	1	1700	5
356	1	1700	9
356	1	1700	10
356	1	1700	11
356	1	1700	15
356	1	1700	17
356	1	1700	18
356	1	1700	19
356	1	1700	25
356	1	1701	4
356	1	1701	9
356	1	1701	11
356	1	1701	15
356	1	1701	19
356	1	1701	25
356	1	1702	9
356	1	1703	0
357	1	1704	1
357	1	1704	3
357	1	1704	5
357	1	1704	8
357	1	1704	15
357	1	1704	17
357	1	1704	21
357	1	1704	23
357	1	1704	24
357	1	1704	25
357	1	1705	1
357	1	1705	8
357	1	1705	15
357	1	1705	25
357	1	1706	1
357	1	1706	25
357	1	1707	1
357	1	1708	0
358	1	1709	2
358	1	1709	6
358	1	1709	7
358	1	1709	8
358	1	1709	9
358	1	1709	10
358	1	1709	14
358	1	1709	16
358	1	1709	17
358	1	1709	25
358	1	1710	8
358	1	1710	14
358	1	1710	16
358	1	1711	16
358	1	1712	0
359	1	1713	2
359	1	1713	3
359	1	1713	5
359	1	1713	6
359	1	1713	7
359	1	1713	11
359	1	1713	14
359	1	1713	18
359	1	1713	22
359	1	1713	25
359	1	1714	2
359	1	1714	11
359	1	1714	25
359	1	1715	0
360	1	1716	2
360	1	1716	6
360	1	1716	8
360	1	1716	9
360	1	1716	14
360	1	1716	15
360	1	1716	18
360	1	1716	19
360	1	1716	20
360	1	1716	21
360	1	1717	2
360	1	1717	6
360	1	1717	18
360	1	1717	19
360	1	1717	20
360	1	1718	19
360	1	1719	19
360	1	1720	19
360	1	1721	0
361	1	1722	1
361	1	1722	3
361	1	1722	6
361	1	1722	9
361	1	1722	10
361	1	1722	13
361	1	1722	16
361	1	1722	18
361	1	1722	20
361	1	1722	24
361	1	1723	3
361	1	1723	9
361	1	1723	16
361	1	1723	20
361	1	1723	24
361	1	1724	3
361	1	1724	24
361	1	1725	3
361	1	1726	0
362	1	1727	3
362	1	1727	4
362	1	1727	8
362	1	1727	11
362	1	1727	12
362	1	1727	17
362	1	1727	18
362	1	1727	19
362	1	1727	23
362	1	1727	25
362	1	1728	4
362	1	1728	18
362	1	1728	19
362	1	1728	23
362	1	1728	25
362	1	1729	19
362	1	1729	23
362	1	1730	0
363	1	1731	2
363	1	1731	4
363	1	1731	6
363	1	1731	11
363	1	1731	12
363	1	1731	15
363	1	1731	16
363	1	1731	18
363	1	1731	21
363	1	1731	23
363	1	1732	2
363	1	1732	4
363	1	1732	6
363	1	1732	11
363	1	1732	15
363	1	1732	16
363	1	1732	23
363	1	1733	6
363	1	1733	11
363	1	1734	0
364	1	1735	4
364	1	1735	5
364	1	1735	7
364	1	1735	8
364	1	1735	9
364	1	1735	11
364	1	1735	16
364	1	1735	17
364	1	1735	18
364	1	1735	22
364	1	1736	4
364	1	1736	5
364	1	1736	8
364	1	1736	17
364	1	1737	8
364	1	1737	17
364	1	1738	8
364	1	1739	0
365	1	1740	7
365	1	1740	12
365	1	1740	13
365	1	1740	14
365	1	1740	15
365	1	1740	17
365	1	1740	20
365	1	1740	21
365	1	1740	23
365	1	1740	25
365	1	1741	7
365	1	1741	13
365	1	1741	14
365	1	1742	7
365	1	1742	13
365	1	1743	0
366	1	1744	2
366	1	1744	3
366	1	1744	4
366	1	1744	7
366	1	1744	8
366	1	1744	9
366	1	1744	14
366	1	1744	16
366	1	1744	22
366	1	1744	25
366	1	1745	14
366	1	1745	22
366	1	1746	14
366	1	1747	14
366	1	1748	14
366	1	1749	14
366	1	1750	14
366	1	1751	14
366	1	1752	14
366	1	1753	14
366	1	1754	0
367	1	1755	4
367	1	1755	5
367	1	1755	6
367	1	1755	7
367	1	1755	10
367	1	1755	12
367	1	1755	14
367	1	1755	15
367	1	1755	17
367	1	1755	24
367	1	1756	4
367	1	1756	10
367	1	1756	14
367	1	1756	15
367	1	1757	0
368	1	1758	3
368	1	1758	5
368	1	1758	6
368	1	1758	11
368	1	1758	15
368	1	1758	16
368	1	1758	18
368	1	1758	21
368	1	1758	24
368	1	1758	25
368	1	1759	11
368	1	1759	21
368	1	1759	24
368	1	1759	25
368	1	1760	11
368	1	1760	21
368	1	1761	0
369	1	1762	3
369	1	1762	4
369	1	1762	9
369	1	1762	10
369	1	1762	11
369	1	1762	13
369	1	1762	14
369	1	1762	18
369	1	1762	19
369	1	1762	24
369	1	1763	18
369	1	1763	19
369	1	1764	18
369	1	1765	0
370	1	1766	2
370	1	1766	4
370	1	1766	5
370	1	1766	6
370	1	1766	17
370	1	1766	18
370	1	1766	19
370	1	1766	22
370	1	1766	24
370	1	1766	25
370	1	1767	17
370	1	1767	18
370	1	1767	22
370	1	1768	0
371	1	1769	2
371	1	1769	4
371	1	1769	6
371	1	1769	9
371	1	1769	11
371	1	1769	15
371	1	1769	19
371	1	1769	21
371	1	1769	22
371	1	1769	24
371	1	1770	6
371	1	1770	9
371	1	1770	24
371	1	1771	9
371	1	1772	0
372	1	1773	3
372	1	1773	4
372	1	1773	6
372	1	1773	7
372	1	1773	11
372	1	1773	12
372	1	1773	14
372	1	1773	20
372	1	1773	22
372	1	1773	23
372	1	1774	4
372	1	1774	6
372	1	1774	11
372	1	1775	4
372	1	1776	0
373	1	1777	1
373	1	1777	3
373	1	1777	5
373	1	1777	7
373	1	1777	9
373	1	1777	11
373	1	1777	13
373	1	1777	17
373	1	1777	22
373	1	1777	23
373	1	1778	7
373	1	1778	17
373	1	1778	22
373	1	1779	7
373	1	1779	17
373	1	1780	7
373	1	1781	0
374	1	1782	4
374	1	1782	5
374	1	1782	6
374	1	1782	9
374	1	1782	10
374	1	1782	11
374	1	1782	16
374	1	1782	21
374	1	1782	23
374	1	1782	24
374	1	1783	5
374	1	1783	6
374	1	1783	9
374	1	1783	16
374	1	1784	5
374	1	1784	6
374	1	1784	16
374	1	1785	0
375	1	1786	2
375	1	1786	8
375	1	1786	9
375	1	1786	10
375	1	1786	11
375	1	1786	13
375	1	1786	14
375	1	1786	15
375	1	1786	19
375	1	1786	25
375	1	1787	8
375	1	1787	9
375	1	1787	13
375	1	1787	15
375	1	1788	8
375	1	1789	0
376	1	1790	4
376	1	1790	5
376	1	1790	7
376	1	1790	9
376	1	1790	10
376	1	1790	14
376	1	1790	16
376	1	1790	19
376	1	1790	20
376	1	1790	22
376	1	1791	9
376	1	1791	14
376	1	1791	16
376	1	1792	0
377	1	1793	4
377	1	1793	7
377	1	1793	8
377	1	1793	9
377	1	1793	12
377	1	1793	14
377	1	1793	15
377	1	1793	17
377	1	1793	22
377	1	1793	25
377	1	1794	9
377	1	1794	12
377	1	1794	14
377	1	1794	15
377	1	1794	17
377	1	1795	12
377	1	1795	14
377	1	1795	15
377	1	1796	14
377	1	1797	0
378	1	1798	1
378	1	1798	6
378	1	1798	8
378	1	1798	10
378	1	1798	11
378	1	1798	17
378	1	1798	18
378	1	1798	22
378	1	1798	24
378	1	1798	25
378	1	1799	1
378	1	1799	6
378	1	1799	17
378	1	1800	17
378	1	1801	0
379	1	1802	3
379	1	1802	4
379	1	1802	6
379	1	1802	7
379	1	1802	9
379	1	1802	10
379	1	1802	13
379	1	1802	17
379	1	1802	18
379	1	1802	22
379	1	1803	10
379	1	1803	13
379	1	1803	22
379	1	1804	0
380	1	1805	3
380	1	1805	7
380	1	1805	8
380	1	1805	11
380	1	1805	12
380	1	1805	13
380	1	1805	17
380	1	1805	19
380	1	1805	21
380	1	1805	25
380	1	1806	3
380	1	1806	8
380	1	1806	12
380	1	1806	13
380	1	1806	17
380	1	1807	12
380	1	1808	0
381	1	1809	3
381	1	1809	7
381	1	1809	8
381	1	1809	10
381	1	1809	11
381	1	1809	12
381	1	1809	15
381	1	1809	19
381	1	1809	21
381	1	1809	22
381	1	1810	8
381	1	1810	10
381	1	1810	11
381	1	1810	15
381	1	1811	11
381	1	1811	15
381	1	1812	15
381	1	1813	0
382	1	1814	4
382	1	1814	6
382	1	1814	8
382	1	1814	9
382	1	1814	10
382	1	1814	11
382	1	1814	13
382	1	1814	17
382	1	1814	20
382	1	1814	22
382	1	1815	4
382	1	1815	8
382	1	1815	9
382	1	1815	17
382	1	1815	22
382	1	1816	17
382	1	1816	22
382	1	1817	0
383	1	1818	2
383	1	1818	3
383	1	1818	7
383	1	1818	12
383	1	1818	13
383	1	1818	17
383	1	1818	18
383	1	1818	20
383	1	1818	22
383	1	1818	25
383	1	1819	2
383	1	1819	3
383	1	1819	7
383	1	1819	22
383	1	1819	25
383	1	1820	2
383	1	1820	3
383	1	1821	0
384	1	1822	2
384	1	1822	3
384	1	1822	5
384	1	1822	7
384	1	1822	8
384	1	1822	10
384	1	1822	11
384	1	1822	15
384	1	1822	22
384	1	1822	23
384	1	1823	2
384	1	1823	11
384	1	1823	23
384	1	1824	0
385	1	1825	2
385	1	1825	4
385	1	1825	5
385	1	1825	6
385	1	1825	12
385	1	1825	13
385	1	1825	18
385	1	1825	19
385	1	1825	24
385	1	1825	25
385	1	1826	4
385	1	1826	6
385	1	1826	18
385	1	1826	24
385	1	1827	0
386	1	1828	3
386	1	1828	4
386	1	1828	10
386	1	1828	14
386	1	1828	16
386	1	1828	17
386	1	1828	18
386	1	1828	20
386	1	1828	22
386	1	1828	25
386	1	1829	14
386	1	1829	17
386	1	1829	18
386	1	1829	20
386	1	1829	25
386	1	1830	25
386	1	1831	25
386	1	1832	0
387	1	1833	2
387	1	1833	3
387	1	1833	4
387	1	1833	5
387	1	1833	6
387	1	1833	8
387	1	1833	10
387	1	1833	13
387	1	1833	17
387	1	1833	22
387	1	1834	3
387	1	1834	4
387	1	1834	10
387	1	1835	3
387	1	1835	10
387	1	1836	10
387	1	1837	10
387	1	1838	0
388	1	1839	2
388	1	1839	5
388	1	1839	10
388	1	1839	11
388	1	1839	12
388	1	1839	13
388	1	1839	16
388	1	1839	20
388	1	1839	21
388	1	1839	22
388	1	1840	5
388	1	1840	20
388	1	1840	22
388	1	1841	5
388	1	1841	20
388	1	1842	0
389	1	1843	1
389	1	1843	2
389	1	1843	3
389	1	1843	5
389	1	1843	9
389	1	1843	10
389	1	1843	13
389	1	1843	18
389	1	1843	23
389	1	1843	25
389	1	1844	2
389	1	1844	9
389	1	1844	10
389	1	1844	13
389	1	1844	18
389	1	1845	2
389	1	1845	9
389	1	1845	13
389	1	1846	13
389	1	1847	13
389	1	1848	0
390	1	1849	2
390	1	1849	3
390	1	1849	4
390	1	1849	6
390	1	1849	7
390	1	1849	8
390	1	1849	10
390	1	1849	15
390	1	1849	16
390	1	1849	20
390	1	1850	2
390	1	1850	3
390	1	1850	6
390	1	1850	8
390	1	1851	2
390	1	1851	3
390	1	1852	2
390	1	1853	2
390	1	1854	2
390	1	1855	2
390	1	1856	2
390	1	1857	0
391	1	1858	1
391	1	1858	5
391	1	1858	6
391	1	1858	10
391	1	1858	12
391	1	1858	14
391	1	1858	16
391	1	1858	19
391	1	1858	23
391	1	1858	24
391	1	1859	1
391	1	1859	5
391	1	1859	10
391	1	1859	14
391	1	1859	23
391	1	1860	14
391	1	1861	0
392	1	1862	1
392	1	1862	6
392	1	1862	8
392	1	1862	9
392	1	1862	12
392	1	1862	14
392	1	1862	15
392	1	1862	17
392	1	1862	22
392	1	1862	25
392	1	1863	1
392	1	1863	12
392	1	1863	15
392	1	1863	17
392	1	1864	1
392	1	1864	15
392	1	1864	17
392	1	1865	1
392	1	1865	15
392	1	1866	15
392	1	1867	0
393	1	1868	3
393	1	1868	7
393	1	1868	9
393	1	1868	12
393	1	1868	15
393	1	1868	18
393	1	1868	20
393	1	1868	22
393	1	1868	23
393	1	1868	25
393	1	1869	3
393	1	1869	7
393	1	1869	9
393	1	1869	12
393	1	1869	20
393	1	1870	9
393	1	1870	12
393	1	1871	9
393	1	1871	12
393	1	1872	12
393	1	1873	0
394	1	1874	2
394	1	1874	3
394	1	1874	4
394	1	1874	7
394	1	1874	11
394	1	1874	12
394	1	1874	15
394	1	1874	16
394	1	1874	18
394	1	1874	23
394	1	1875	2
394	1	1875	11
394	1	1875	12
394	1	1875	15
394	1	1876	12
394	1	1876	15
394	1	1877	0
395	1	1878	7
395	1	1878	9
395	1	1878	11
395	1	1878	13
395	1	1878	14
395	1	1878	16
395	1	1878	18
395	1	1878	20
395	1	1878	21
395	1	1878	22
395	1	1879	7
395	1	1879	9
395	1	1879	14
395	1	1879	18
395	1	1879	22
395	1	1880	14
395	1	1881	0
396	1	1882	2
396	1	1882	6
396	1	1882	7
396	1	1882	10
396	1	1882	17
396	1	1882	18
396	1	1882	19
396	1	1882	20
396	1	1882	21
396	1	1882	25
396	1	1883	6
396	1	1883	7
396	1	1883	10
396	1	1883	19
396	1	1883	20
396	1	1883	25
396	1	1884	10
396	1	1884	19
396	1	1884	20
396	1	1885	19
396	1	1885	20
396	1	1886	0
397	1	1887	2
397	1	1887	5
397	1	1887	13
397	1	1887	15
397	1	1887	19
397	1	1887	20
397	1	1887	21
397	1	1887	23
397	1	1887	24
397	1	1887	25
397	1	1888	5
397	1	1888	13
397	1	1888	15
397	1	1888	19
397	1	1888	21
397	1	1889	5
397	1	1889	21
397	1	1890	0
398	1	1891	1
398	1	1891	2
398	1	1891	5
398	1	1891	8
398	1	1891	9
398	1	1891	10
398	1	1891	12
398	1	1891	13
398	1	1891	17
398	1	1891	18
398	1	1892	2
398	1	1892	12
398	1	1892	13
398	1	1892	17
398	1	1892	18
398	1	1893	12
398	1	1893	13
398	1	1893	17
398	1	1893	18
398	1	1894	13
398	1	1895	0
399	1	1896	4
399	1	1896	5
399	1	1896	7
399	1	1896	10
399	1	1896	11
399	1	1896	13
399	1	1896	14
399	1	1896	19
399	1	1896	23
399	1	1896	25
399	1	1897	10
399	1	1897	11
399	1	1897	19
399	1	1897	23
399	1	1897	25
399	1	1898	11
399	1	1898	25
399	1	1899	25
399	1	1900	0
400	1	1901	1
400	1	1901	6
400	1	1901	7
400	1	1901	8
400	1	1901	11
400	1	1901	21
400	1	1901	22
400	1	1901	23
400	1	1901	24
400	1	1901	25
400	1	1902	7
400	1	1902	21
400	1	1902	24
400	1	1903	0
401	1	1904	2
401	1	1904	3
401	1	1904	4
401	1	1904	5
401	1	1904	9
401	1	1904	16
401	1	1904	19
401	1	1904	21
401	1	1904	22
401	1	1904	24
401	1	1905	2
401	1	1905	4
401	1	1905	5
401	1	1905	22
401	1	1906	5
401	1	1906	22
401	1	1907	22
401	1	1908	0
402	1	1909	1
402	1	1909	7
402	1	1909	13
402	1	1909	15
402	1	1909	16
402	1	1909	19
402	1	1909	20
402	1	1909	21
402	1	1909	23
402	1	1909	24
402	1	1910	1
402	1	1910	19
402	1	1910	20
402	1	1910	21
402	1	1910	24
402	1	1911	20
402	1	1912	0
403	1	1913	1
403	1	1913	3
403	1	1913	4
403	1	1913	13
403	1	1913	15
403	1	1913	17
403	1	1913	18
403	1	1913	21
403	1	1913	22
403	1	1913	23
403	1	1914	1
403	1	1914	3
403	1	1914	22
403	1	1914	23
403	1	1915	1
403	1	1915	3
403	1	1915	23
403	1	1916	1
403	1	1916	3
403	1	1917	0
404	1	1918	1
404	1	1918	3
404	1	1918	8
404	1	1918	13
404	1	1918	14
404	1	1918	15
404	1	1918	16
404	1	1918	21
404	1	1918	23
404	1	1918	25
404	1	1919	8
404	1	1919	13
404	1	1919	14
404	1	1919	16
404	1	1919	25
404	1	1920	8
404	1	1920	16
404	1	1921	0
405	1	1922	1
405	1	1922	9
405	1	1922	11
405	1	1922	13
405	1	1922	14
405	1	1922	15
405	1	1922	20
405	1	1922	21
405	1	1922	22
405	1	1922	24
405	1	1923	9
405	1	1923	13
405	1	1923	15
405	1	1923	21
405	1	1924	15
405	1	1924	21
405	1	1925	15
405	1	1926	0
406	1	1927	3
406	1	1927	6
406	1	1927	7
406	1	1927	9
406	1	1927	12
406	1	1927	14
406	1	1927	16
406	1	1927	19
406	1	1927	20
406	1	1927	25
406	1	1928	12
406	1	1928	14
406	1	1928	20
406	1	1929	12
406	1	1929	14
406	1	1930	12
406	1	1931	0
407	1	1932	1
407	1	1932	3
407	1	1932	5
407	1	1932	7
407	1	1932	13
407	1	1932	15
407	1	1932	18
407	1	1932	21
407	1	1932	23
407	1	1932	25
407	1	1933	3
407	1	1933	5
407	1	1933	15
407	1	1933	18
407	1	1934	15
407	1	1934	18
407	1	1935	0
408	1	1936	1
408	1	1936	7
408	1	1936	9
408	1	1936	10
408	1	1936	12
408	1	1936	16
408	1	1936	18
408	1	1936	22
408	1	1936	23
408	1	1936	24
408	1	1937	1
408	1	1937	7
408	1	1937	16
408	1	1937	18
408	1	1938	1
408	1	1939	1
408	1	1940	0
409	1	1941	2
409	1	1941	6
409	1	1941	7
409	1	1941	9
409	1	1941	11
409	1	1941	15
409	1	1941	18
409	1	1941	19
409	1	1941	21
409	1	1941	23
409	1	1942	6
409	1	1942	9
409	1	1942	19
409	1	1942	21
409	1	1942	23
409	1	1943	21
409	1	1944	21
409	1	1945	21
409	1	1946	0
410	1	1947	1
410	1	1947	3
410	1	1947	4
410	1	1947	7
410	1	1947	8
410	1	1947	10
410	1	1947	12
410	1	1947	17
410	1	1947	20
410	1	1947	21
410	1	1948	4
410	1	1948	8
410	1	1948	10
410	1	1949	4
410	1	1950	0
411	1	1951	1
411	1	1951	2
411	1	1951	5
411	1	1951	7
411	1	1951	8
411	1	1951	14
411	1	1951	15
411	1	1951	17
411	1	1951	21
411	1	1951	24
411	1	1952	1
411	1	1952	2
411	1	1952	8
411	1	1952	15
411	1	1953	2
411	1	1953	8
411	1	1954	0
412	1	1955	3
412	1	1955	6
412	1	1955	7
412	1	1955	8
412	1	1955	10
412	1	1955	11
412	1	1955	13
412	1	1955	17
412	1	1955	18
412	1	1955	21
412	1	1956	11
412	1	1956	13
412	1	1956	17
412	1	1956	18
412	1	1957	13
412	1	1957	18
412	1	1958	13
412	1	1959	0
413	1	1960	1
413	1	1960	4
413	1	1960	5
413	1	1960	6
413	1	1960	8
413	1	1960	11
413	1	1960	14
413	1	1960	16
413	1	1960	19
413	1	1960	22
413	1	1961	1
413	1	1961	6
413	1	1961	8
413	1	1961	11
413	1	1961	16
413	1	1962	8
413	1	1962	11
413	1	1963	0
414	1	1964	4
414	1	1964	6
414	1	1964	7
414	1	1964	11
414	1	1964	18
414	1	1964	20
414	1	1964	21
414	1	1964	22
414	1	1964	24
414	1	1964	25
414	1	1965	7
414	1	1965	11
414	1	1965	18
414	1	1966	11
414	1	1967	0
415	1	1968	6
415	1	1968	8
415	1	1968	10
415	1	1968	11
415	1	1968	12
415	1	1968	15
415	1	1968	17
415	1	1968	19
415	1	1968	21
415	1	1968	24
415	1	1969	8
415	1	1969	10
415	1	1969	11
415	1	1969	12
415	1	1969	17
415	1	1969	21
415	1	1970	0
416	1	1971	1
416	1	1971	2
416	1	1971	4
416	1	1971	5
416	1	1971	7
416	1	1971	11
416	1	1971	12
416	1	1971	20
416	1	1971	22
416	1	1971	24
416	1	1972	1
416	1	1972	2
416	1	1972	4
416	1	1972	5
416	1	1972	24
416	1	1973	1
416	1	1973	4
416	1	1973	5
416	1	1973	24
416	1	1974	0
417	1	1975	1
417	1	1975	3
417	1	1975	4
417	1	1975	6
417	1	1975	14
417	1	1975	15
417	1	1975	18
417	1	1975	19
417	1	1975	21
417	1	1975	24
417	1	1976	4
417	1	1976	6
417	1	1976	21
417	1	1977	6
417	1	1977	21
417	1	1978	21
417	1	1979	0
418	1	1980	1
418	1	1980	2
418	1	1980	6
418	1	1980	8
418	1	1980	11
418	1	1980	12
418	1	1980	14
418	1	1980	15
418	1	1980	20
418	1	1980	25
418	1	1981	8
418	1	1981	11
418	1	1981	14
418	1	1982	8
418	1	1982	11
418	1	1983	0
419	1	1984	1
419	1	1984	3
419	1	1984	6
419	1	1984	7
419	1	1984	8
419	1	1984	9
419	1	1984	15
419	1	1984	17
419	1	1984	18
419	1	1984	22
419	1	1985	8
419	1	1985	18
419	1	1986	0
420	1	1987	1
420	1	1987	7
420	1	1987	8
420	1	1987	9
420	1	1987	14
420	1	1987	18
420	1	1987	20
420	1	1987	23
420	1	1987	24
420	1	1987	25
420	1	1988	1
420	1	1988	8
420	1	1988	18
420	1	1988	20
420	1	1988	25
420	1	1989	8
420	1	1989	18
420	1	1989	20
420	1	1990	18
420	1	1991	0
421	1	1992	1
421	1	1992	2
421	1	1992	10
421	1	1992	13
421	1	1992	15
421	1	1992	16
421	1	1992	17
421	1	1992	18
421	1	1992	24
421	1	1992	25
421	1	1993	2
421	1	1993	17
421	1	1993	18
421	1	1993	24
421	1	1993	25
421	1	1994	2
421	1	1994	18
421	1	1995	2
421	1	1996	0
422	1	1997	1
422	1	1997	3
422	1	1997	5
422	1	1997	10
422	1	1997	11
422	1	1997	17
422	1	1997	19
422	1	1997	23
422	1	1997	24
422	1	1997	25
422	1	1998	23
422	1	1998	25
422	1	1999	0
423	1	2000	1
423	1	2000	5
423	1	2000	6
423	1	2000	8
423	1	2000	9
423	1	2000	10
423	1	2000	13
423	1	2000	15
423	1	2000	21
423	1	2000	25
605	1	2847	1
605	1	2847	3
605	1	2847	7
605	1	2847	11
605	1	2847	16
605	1	2847	25
605	1	2848	3
605	1	2849	3
605	1	2850	3
605	1	2851	0
606	1	2852	3
606	1	2852	5
606	1	2852	7
606	1	2852	11
606	1	2852	16
606	1	2852	18
606	1	2852	20
606	1	2852	21
606	1	2852	23
606	1	2852	25
606	1	2853	7
606	1	2853	16
606	1	2853	18
606	1	2853	20
606	1	2853	23
606	1	2854	16
606	1	2854	18
606	1	2855	18
606	1	2856	0
607	1	2857	2
607	1	2857	5
607	1	2857	11
607	1	2857	13
607	1	2857	14
607	1	2857	18
607	1	2857	20
607	1	2857	21
607	1	2857	24
607	1	2857	25
607	1	2858	14
607	1	2858	18
607	1	2858	21
607	1	2858	25
607	1	2859	0
608	1	2860	6
608	1	2860	7
608	1	2860	10
608	1	2860	11
608	1	2860	17
608	1	2860	19
608	1	2860	22
608	1	2860	23
608	1	2860	24
608	1	2860	25
608	1	2861	6
608	1	2861	22
608	1	2861	23
608	1	2861	24
608	1	2862	24
608	1	2863	24
608	1	2864	24
608	1	2865	24
608	1	2866	0
609	1	2867	2
609	1	2867	3
609	1	2867	4
609	1	2867	6
609	1	2867	8
609	1	2867	11
609	1	2867	16
609	1	2867	17
609	1	2867	19
609	1	2867	24
609	1	2868	11
609	1	2868	16
609	1	2868	19
609	1	2869	0
610	1	2870	3
610	1	2870	6
610	1	2870	8
610	1	2870	12
610	1	2870	13
610	1	2870	18
610	1	2870	20
610	1	2870	21
610	1	2870	23
610	1	2870	24
610	1	2871	3
610	1	2871	13
610	1	2871	18
610	1	2871	24
610	1	2872	3
610	1	2872	24
610	1	2873	3
610	1	2874	0
611	1	2875	3
611	1	2875	5
611	1	2875	10
611	1	2875	16
611	1	2875	17
611	1	2875	20
611	1	2875	21
611	1	2875	22
611	1	2875	23
611	1	2875	24
611	1	2876	17
611	1	2876	21
611	1	2876	23
611	1	2876	24
611	1	2877	21
611	1	2877	23
611	1	2878	23
611	1	2879	23
611	1	2880	0
423	1	2001	5
423	1	2001	8
423	1	2001	13
423	1	2001	15
423	1	2002	15
423	1	2003	0
424	1	2004	2
424	1	2004	5
424	1	2004	6
424	1	2004	7
424	1	2004	9
424	1	2004	16
424	1	2004	17
424	1	2004	20
424	1	2004	23
424	1	2004	24
424	1	2005	2
424	1	2005	5
424	1	2005	7
424	1	2005	16
424	1	2005	20
424	1	2005	23
424	1	2006	16
424	1	2007	0
425	1	2008	1
425	1	2008	4
425	1	2008	7
425	1	2008	9
425	1	2008	16
425	1	2008	18
425	1	2008	19
425	1	2008	20
425	1	2008	22
425	1	2008	24
425	1	2009	9
425	1	2009	18
425	1	2010	9
425	1	2010	18
425	1	2011	9
425	1	2012	0
426	1	2013	3
426	1	2013	5
426	1	2013	6
426	1	2013	9
426	1	2013	12
426	1	2013	13
426	1	2013	15
426	1	2013	17
426	1	2013	18
426	1	2013	22
426	1	2014	5
426	1	2014	12
426	1	2014	13
426	1	2015	12
426	1	2016	12
426	1	2017	12
426	1	2018	0
427	1	2019	2
427	1	2019	4
427	1	2019	7
427	1	2019	12
427	1	2019	13
427	1	2019	15
427	1	2019	16
427	1	2019	19
427	1	2019	21
427	1	2019	22
427	1	2020	13
427	1	2020	22
427	1	2021	13
427	1	2022	0
428	1	2023	3
428	1	2023	5
428	1	2023	6
428	1	2023	7
428	1	2023	9
428	1	2023	13
428	1	2023	18
428	1	2023	22
428	1	2023	23
428	1	2023	24
428	1	2024	7
428	1	2024	13
428	1	2024	22
428	1	2025	7
428	1	2025	13
428	1	2026	7
428	1	2027	0
429	1	2028	7
429	1	2028	10
429	1	2028	11
429	1	2028	12
429	1	2028	13
429	1	2028	14
429	1	2028	17
429	1	2028	21
429	1	2028	22
429	1	2028	24
429	1	2029	14
429	1	2029	21
429	1	2030	21
429	1	2031	21
429	1	2032	0
430	1	2033	3
430	1	2033	4
430	1	2033	7
430	1	2033	8
430	1	2033	9
430	1	2033	15
430	1	2033	18
430	1	2033	23
430	1	2033	24
430	1	2033	25
430	1	2034	15
430	1	2034	23
430	1	2034	25
430	1	2035	15
430	1	2036	15
430	1	2037	15
430	1	2038	0
431	1	2039	7
431	1	2039	8
431	1	2039	9
431	1	2039	12
431	1	2039	13
431	1	2039	16
431	1	2039	17
431	1	2039	18
431	1	2039	20
431	1	2039	22
431	1	2040	7
431	1	2040	9
431	1	2040	17
431	1	2040	18
431	1	2041	18
431	1	2042	0
432	1	2043	1
432	1	2043	2
432	1	2043	4
432	1	2043	6
432	1	2043	8
432	1	2043	10
432	1	2043	11
432	1	2043	16
432	1	2043	20
432	1	2043	24
432	1	2044	1
432	1	2044	2
432	1	2044	4
432	1	2044	8
432	1	2045	2
432	1	2045	4
432	1	2045	8
432	1	2046	2
432	1	2046	8
432	1	2047	0
433	1	2048	2
433	1	2048	5
433	1	2048	10
433	1	2048	11
433	1	2048	14
433	1	2048	15
433	1	2048	17
433	1	2048	18
433	1	2048	23
433	1	2048	24
433	1	2049	2
433	1	2049	5
433	1	2049	15
433	1	2049	18
433	1	2049	23
433	1	2050	23
433	1	2051	0
434	1	2052	2
434	1	2052	5
434	1	2052	7
434	1	2052	9
434	1	2052	11
434	1	2052	15
434	1	2052	19
434	1	2052	21
434	1	2052	22
434	1	2052	23
434	1	2053	2
434	1	2053	5
434	1	2053	7
434	1	2053	19
434	1	2054	0
435	1	2055	6
435	1	2055	8
435	1	2055	9
435	1	2055	10
435	1	2055	12
435	1	2055	13
435	1	2055	17
435	1	2055	20
435	1	2055	22
435	1	2055	24
435	1	2056	8
435	1	2056	12
435	1	2056	22
435	1	2056	24
435	1	2057	22
435	1	2057	24
435	1	2058	0
436	1	2059	2
436	1	2059	3
436	1	2059	6
436	1	2059	7
436	1	2059	8
436	1	2059	9
436	1	2059	11
436	1	2059	13
436	1	2059	22
436	1	2059	24
436	1	2060	2
436	1	2060	6
436	1	2060	7
436	1	2060	8
436	1	2060	11
436	1	2061	6
436	1	2061	7
436	1	2062	0
437	1	2063	3
437	1	2063	4
437	1	2063	8
437	1	2063	9
437	1	2063	12
437	1	2063	14
437	1	2063	15
437	1	2063	17
437	1	2063	21
437	1	2063	23
437	1	2064	3
437	1	2064	4
437	1	2064	8
437	1	2064	14
437	1	2064	15
437	1	2064	23
437	1	2065	3
437	1	2065	15
437	1	2065	23
437	1	2066	3
437	1	2066	23
437	1	2067	3
437	1	2068	0
438	1	2069	8
438	1	2069	10
438	1	2069	11
438	1	2069	12
438	1	2069	14
438	1	2069	15
438	1	2069	16
438	1	2069	18
438	1	2069	19
438	1	2069	20
438	1	2070	10
438	1	2070	11
438	1	2070	18
438	1	2071	18
438	1	2072	0
439	1	2073	1
439	1	2073	2
439	1	2073	3
439	1	2073	8
439	1	2073	9
439	1	2073	10
439	1	2073	14
439	1	2073	17
439	1	2073	21
439	1	2073	22
439	1	2074	1
439	1	2074	8
439	1	2074	10
439	1	2074	17
439	1	2075	1
439	1	2075	10
439	1	2076	0
440	1	2077	1
440	1	2077	2
440	1	2077	6
440	1	2077	9
440	1	2077	17
440	1	2077	18
440	1	2077	19
440	1	2077	20
440	1	2077	22
440	1	2077	23
440	1	2078	9
440	1	2078	20
440	1	2078	23
440	1	2079	20
440	1	2080	20
440	1	2081	0
441	1	2082	2
441	1	2082	3
441	1	2082	11
441	1	2082	12
441	1	2082	14
441	1	2082	18
441	1	2082	21
441	1	2082	22
441	1	2082	23
441	1	2082	24
441	1	2083	2
441	1	2083	3
441	1	2083	18
441	1	2084	2
441	1	2084	18
441	1	2085	2
441	1	2086	2
441	1	2087	2
441	1	2088	0
442	1	2089	3
442	1	2089	4
442	1	2089	7
442	1	2089	14
442	1	2089	15
442	1	2089	17
442	1	2089	18
442	1	2089	21
442	1	2089	22
442	1	2089	24
442	1	2090	3
442	1	2090	4
442	1	2090	7
442	1	2090	17
442	1	2090	21
442	1	2091	21
442	1	2092	21
442	1	2093	0
443	1	2094	1
443	1	2094	3
443	1	2094	7
443	1	2094	13
443	1	2094	15
443	1	2094	16
443	1	2094	17
443	1	2094	20
443	1	2094	21
443	1	2094	22
443	1	2095	3
443	1	2095	7
443	1	2095	13
443	1	2095	16
443	1	2095	21
443	1	2096	16
443	1	2097	0
444	1	2098	1
444	1	2098	2
444	1	2098	3
444	1	2098	5
444	1	2098	6
444	1	2098	11
444	1	2098	14
444	1	2098	21
444	1	2098	23
444	1	2098	24
444	1	2099	3
444	1	2099	6
444	1	2099	21
444	1	2099	23
444	1	2100	0
445	1	2101	4
445	1	2101	5
445	1	2101	6
445	1	2101	7
445	1	2101	9
445	1	2101	12
445	1	2101	13
445	1	2101	15
445	1	2101	16
445	1	2101	22
445	1	2102	6
445	1	2102	7
445	1	2103	6
445	1	2104	0
446	1	2105	1
446	1	2105	2
446	1	2105	4
446	1	2105	5
446	1	2105	6
446	1	2105	11
446	1	2105	12
446	1	2105	15
446	1	2105	23
446	1	2105	24
446	1	2106	1
446	1	2106	5
446	1	2106	23
446	1	2107	23
446	1	2108	23
446	1	2109	0
447	1	2110	1
447	1	2110	3
447	1	2110	4
447	1	2110	5
447	1	2110	7
447	1	2110	9
447	1	2110	12
447	1	2110	19
447	1	2110	20
447	1	2110	23
447	1	2111	7
447	1	2112	0
448	1	2113	3
448	1	2113	5
448	1	2113	6
448	1	2113	12
448	1	2113	14
448	1	2113	15
448	1	2113	18
448	1	2113	19
448	1	2113	21
448	1	2113	23
448	1	2114	3
448	1	2114	6
448	1	2114	12
448	1	2114	14
448	1	2114	23
448	1	2115	6
448	1	2115	14
448	1	2115	23
448	1	2116	23
448	1	2117	23
448	1	2118	23
448	1	2119	0
449	1	2120	1
449	1	2120	3
449	1	2120	6
449	1	2120	7
449	1	2120	10
449	1	2120	11
449	1	2120	15
449	1	2120	16
449	1	2120	19
449	1	2120	24
449	1	2121	3
449	1	2121	6
449	1	2121	10
449	1	2121	11
449	1	2121	15
449	1	2121	16
449	1	2121	24
449	1	2122	6
449	1	2122	16
449	1	2122	24
449	1	2123	16
449	1	2124	0
450	1	2125	2
450	1	2125	3
450	1	2125	4
450	1	2125	5
450	1	2125	6
450	1	2125	7
450	1	2125	9
450	1	2125	14
450	1	2125	18
450	1	2125	22
450	1	2126	2
450	1	2126	6
450	1	2126	14
450	1	2126	18
450	1	2127	0
451	1	2128	1
451	1	2128	5
451	1	2128	8
451	1	2128	12
451	1	2128	13
451	1	2128	15
451	1	2128	19
451	1	2128	20
451	1	2128	21
451	1	2128	24
451	1	2129	5
451	1	2129	12
451	1	2129	13
451	1	2130	5
451	1	2131	5
451	1	2132	5
451	1	2133	5
451	1	2134	5
451	1	2135	0
452	1	2136	1
452	1	2136	5
452	1	2136	8
452	1	2136	11
452	1	2136	12
452	1	2136	15
452	1	2136	17
452	1	2136	21
452	1	2136	22
452	1	2136	23
452	1	2137	1
452	1	2137	5
452	1	2137	8
452	1	2137	15
452	1	2137	22
452	1	2138	1
452	1	2138	15
452	1	2139	15
452	1	2140	0
453	1	2141	6
453	1	2141	11
453	1	2141	12
453	1	2141	13
453	1	2141	15
453	1	2141	16
453	1	2141	17
453	1	2141	19
453	1	2141	20
453	1	2141	21
453	1	2142	13
453	1	2142	15
453	1	2142	19
453	1	2142	21
453	1	2143	13
453	1	2143	15
453	1	2144	0
454	1	2145	1
454	1	2145	3
454	1	2145	4
454	1	2145	9
454	1	2145	11
454	1	2145	16
454	1	2145	18
454	1	2145	19
454	1	2145	21
454	1	2145	22
454	1	2146	3
454	1	2147	0
455	1	2148	2
455	1	2148	5
455	1	2148	6
455	1	2148	9
455	1	2148	10
455	1	2148	12
455	1	2148	13
455	1	2148	17
455	1	2148	19
455	1	2148	21
455	1	2149	5
455	1	2149	6
455	1	2149	19
455	1	2149	21
455	1	2150	6
455	1	2150	19
455	1	2151	19
455	1	2152	19
455	1	2153	19
455	1	2154	0
456	1	2155	5
456	1	2155	7
456	1	2155	8
456	1	2155	10
456	1	2155	11
456	1	2155	12
456	1	2155	16
456	1	2155	23
456	1	2155	24
456	1	2155	25
456	1	2156	11
456	1	2156	16
456	1	2156	24
456	1	2156	25
456	1	2157	11
456	1	2158	11
456	1	2159	11
456	1	2160	0
457	1	2161	4
457	1	2161	8
457	1	2161	10
457	1	2161	11
457	1	2161	12
457	1	2161	16
457	1	2161	17
457	1	2161	20
457	1	2161	21
457	1	2161	23
457	1	2162	4
457	1	2162	11
457	1	2162	20
457	1	2162	23
457	1	2163	0
458	1	2164	1
458	1	2164	4
458	1	2164	5
458	1	2164	6
458	1	2164	7
458	1	2164	9
458	1	2164	12
458	1	2164	18
458	1	2164	22
458	1	2164	23
458	1	2165	4
458	1	2165	7
458	1	2165	9
458	1	2165	12
458	1	2166	7
458	1	2167	0
459	1	2168	2
459	1	2168	5
459	1	2168	7
459	1	2168	9
459	1	2168	15
459	1	2168	18
459	1	2168	19
459	1	2168	20
459	1	2168	22
459	1	2168	24
459	1	2169	7
459	1	2169	9
459	1	2169	15
459	1	2169	18
459	1	2169	19
459	1	2170	15
459	1	2171	0
460	1	2172	1
460	1	2172	2
460	1	2172	3
460	1	2172	4
460	1	2172	5
460	1	2172	7
460	1	2172	12
460	1	2172	18
460	1	2172	21
460	1	2172	24
460	1	2173	4
460	1	2173	5
460	1	2173	7
460	1	2173	24
460	1	2174	4
460	1	2175	4
460	1	2176	0
461	1	2177	2
461	1	2177	5
461	1	2177	6
461	1	2177	9
461	1	2177	11
461	1	2177	13
461	1	2177	18
461	1	2177	21
461	1	2177	23
461	1	2177	25
461	1	2178	6
461	1	2178	21
461	1	2178	25
461	1	2179	0
462	1	2180	2
462	1	2180	4
462	1	2180	5
462	1	2180	12
462	1	2180	15
462	1	2180	17
462	1	2180	19
462	1	2180	22
462	1	2180	23
462	1	2180	25
462	1	2181	4
462	1	2181	12
462	1	2181	19
462	1	2182	4
462	1	2183	0
463	1	2184	1
463	1	2184	2
463	1	2184	3
463	1	2184	4
463	1	2184	6
463	1	2184	8
463	1	2184	13
463	1	2184	16
463	1	2184	18
463	1	2184	23
463	1	2185	2
463	1	2185	4
463	1	2185	6
463	1	2185	23
463	1	2186	2
463	1	2187	2
463	1	2188	2
463	1	2189	2
463	1	2190	0
464	1	2191	1
464	1	2191	2
464	1	2191	7
464	1	2191	8
464	1	2191	9
464	1	2191	12
464	1	2191	16
464	1	2191	22
464	1	2191	24
464	1	2191	25
464	1	2192	1
464	1	2192	8
464	1	2192	9
464	1	2192	16
464	1	2192	24
464	1	2193	1
464	1	2193	8
464	1	2193	16
464	1	2194	1
464	1	2194	16
464	1	2195	1
464	1	2196	1
464	1	2197	0
465	1	2198	2
465	1	2198	3
465	1	2198	6
465	1	2198	8
465	1	2198	10
465	1	2198	14
465	1	2198	16
465	1	2198	19
465	1	2198	24
465	1	2198	25
465	1	2199	3
465	1	2199	8
465	1	2199	10
465	1	2199	16
465	1	2199	25
465	1	2200	3
465	1	2201	0
466	1	2202	2
466	1	2202	3
466	1	2202	4
466	1	2202	6
466	1	2202	7
466	1	2202	8
466	1	2202	11
466	1	2202	12
466	1	2202	19
466	1	2202	23
466	1	2203	4
466	1	2203	6
466	1	2203	8
466	1	2203	11
466	1	2203	19
466	1	2204	8
466	1	2204	19
466	1	2205	8
466	1	2206	0
467	1	2207	1
467	1	2207	2
467	1	2207	4
467	1	2207	15
467	1	2207	16
467	1	2207	18
467	1	2207	19
467	1	2207	21
467	1	2207	23
467	1	2207	24
467	1	2208	1
467	1	2208	2
467	1	2209	2
467	1	2210	2
467	1	2211	2
467	1	2212	2
467	1	2213	2
467	1	2214	2
467	1	2215	0
468	1	2216	5
468	1	2216	7
468	1	2216	8
468	1	2216	11
468	1	2216	12
468	1	2216	16
468	1	2216	18
468	1	2216	20
468	1	2216	23
468	1	2216	24
468	1	2217	5
468	1	2217	8
468	1	2217	12
468	1	2217	24
468	1	2218	8
468	1	2219	0
469	1	2220	2
469	1	2220	3
469	1	2220	4
469	1	2220	11
469	1	2220	14
469	1	2220	15
469	1	2220	17
469	1	2220	19
469	1	2220	21
469	1	2220	22
469	1	2221	11
469	1	2221	14
469	1	2221	15
469	1	2221	17
469	1	2221	19
469	1	2221	21
469	1	2222	11
469	1	2222	15
469	1	2222	17
469	1	2222	21
469	1	2223	15
469	1	2223	17
469	1	2224	17
469	1	2225	0
470	1	2226	2
470	1	2226	6
470	1	2226	7
470	1	2226	8
470	1	2226	11
470	1	2226	18
470	1	2226	20
470	1	2226	23
470	1	2226	24
470	1	2226	25
470	1	2227	6
470	1	2227	18
470	1	2227	25
470	1	2228	25
470	1	2229	0
471	1	2230	1
471	1	2230	2
471	1	2230	5
471	1	2230	7
471	1	2230	12
471	1	2230	16
471	1	2230	21
471	1	2230	22
471	1	2230	23
471	1	2230	25
471	1	2231	2
471	1	2231	12
471	1	2231	21
471	1	2231	23
471	1	2232	21
471	1	2233	0
472	1	2234	4
472	1	2234	5
472	1	2234	8
472	1	2234	9
472	1	2234	10
472	1	2234	12
472	1	2234	13
472	1	2234	16
472	1	2234	19
472	1	2234	23
472	1	2235	5
472	1	2235	9
472	1	2235	13
472	1	2236	13
472	1	2237	0
473	1	2238	2
473	1	2238	8
473	1	2238	9
473	1	2238	12
473	1	2238	13
473	1	2238	17
473	1	2238	21
473	1	2238	22
473	1	2238	23
473	1	2238	24
473	1	2239	8
473	1	2239	9
473	1	2239	12
473	1	2239	21
473	1	2240	8
473	1	2240	21
473	1	2241	0
474	1	2242	1
474	1	2242	2
474	1	2242	6
474	1	2242	7
474	1	2242	13
474	1	2242	14
474	1	2242	15
474	1	2242	18
474	1	2242	23
474	1	2242	24
474	1	2243	2
474	1	2243	7
474	1	2243	13
474	1	2243	23
474	1	2244	2
474	1	2244	7
474	1	2245	0
475	1	2246	1
475	1	2246	6
475	1	2246	9
475	1	2246	16
475	1	2246	17
475	1	2246	19
475	1	2246	21
475	1	2246	22
475	1	2246	23
475	1	2246	24
475	1	2247	16
475	1	2247	21
475	1	2247	23
475	1	2248	21
475	1	2249	0
476	1	2250	1
476	1	2250	2
476	1	2250	3
476	1	2250	7
476	1	2250	8
476	1	2250	9
476	1	2250	11
476	1	2250	15
476	1	2250	16
476	1	2250	17
476	1	2251	1
476	1	2251	3
476	1	2251	8
476	1	2251	11
476	1	2251	16
476	1	2251	17
476	1	2252	3
476	1	2252	11
476	1	2253	11
476	1	2254	11
476	1	2255	0
477	1	2256	2
477	1	2256	7
477	1	2256	14
477	1	2256	15
477	1	2256	17
477	1	2256	18
477	1	2256	19
477	1	2256	21
477	1	2256	22
477	1	2256	25
477	1	2257	2
477	1	2257	14
477	1	2257	17
477	1	2257	19
477	1	2257	21
477	1	2257	25
477	1	2258	2
477	1	2258	21
477	1	2258	25
477	1	2259	2
477	1	2259	21
477	1	2260	21
477	1	2261	21
477	1	2262	0
478	1	2263	4
478	1	2263	5
478	1	2263	6
478	1	2263	9
478	1	2263	12
478	1	2263	13
478	1	2263	17
478	1	2263	20
478	1	2263	21
478	1	2263	24
478	1	2264	13
478	1	2264	20
478	1	2264	21
478	1	2264	24
478	1	2265	21
478	1	2265	24
478	1	2266	0
479	1	2267	1
479	1	2267	4
479	1	2267	8
479	1	2267	11
479	1	2267	12
479	1	2267	16
479	1	2267	18
479	1	2267	21
479	1	2267	23
479	1	2267	25
479	1	2268	4
479	1	2268	16
479	1	2269	16
479	1	2270	0
480	1	2271	1
480	1	2271	4
480	1	2271	9
480	1	2271	12
480	1	2271	13
480	1	2271	14
480	1	2271	15
480	1	2271	20
480	1	2271	22
480	1	2271	25
480	1	2272	4
480	1	2272	9
480	1	2272	12
480	1	2272	20
480	1	2272	25
480	1	2273	20
480	1	2274	0
481	1	2275	3
481	1	2275	6
481	1	2275	8
481	1	2275	9
481	1	2275	17
481	1	2275	18
481	1	2275	22
481	1	2275	23
481	1	2275	24
481	1	2275	25
481	1	2276	3
481	1	2276	6
481	1	2276	8
481	1	2276	9
481	1	2276	22
481	1	2276	23
481	1	2276	24
481	1	2276	25
481	1	2277	6
481	1	2277	8
481	1	2277	9
481	1	2277	25
481	1	2278	8
481	1	2278	9
481	1	2278	25
481	1	2279	9
481	1	2280	0
482	1	2281	1
482	1	2281	4
482	1	2281	8
482	1	2281	12
482	1	2281	13
482	1	2281	19
482	1	2281	22
482	1	2281	23
482	1	2281	24
482	1	2281	25
482	1	2282	8
482	1	2282	19
482	1	2282	22
482	1	2282	25
482	1	2283	8
482	1	2284	0
483	1	2285	3
483	1	2285	4
483	1	2285	5
483	1	2285	9
483	1	2285	11
483	1	2285	14
483	1	2285	17
483	1	2285	19
483	1	2285	21
483	1	2285	25
483	1	2286	4
483	1	2286	5
483	1	2286	9
483	1	2286	14
483	1	2286	19
483	1	2286	21
483	1	2287	5
483	1	2287	21
483	1	2288	0
484	1	2289	3
484	1	2289	4
484	1	2289	6
484	1	2289	9
484	1	2289	11
484	1	2289	13
484	1	2289	18
484	1	2289	21
484	1	2289	23
484	1	2289	24
484	1	2290	6
484	1	2290	18
484	1	2290	21
484	1	2291	18
484	1	2292	0
485	1	2293	3
485	1	2293	6
485	1	2293	7
485	1	2293	10
485	1	2293	14
485	1	2293	15
485	1	2293	17
485	1	2293	23
485	1	2293	24
485	1	2293	25
485	1	2294	3
485	1	2294	14
485	1	2295	3
485	1	2296	0
486	1	2297	1
486	1	2297	4
486	1	2297	5
486	1	2297	6
486	1	2297	8
486	1	2297	10
486	1	2297	12
486	1	2297	16
486	1	2297	19
486	1	2297	23
486	1	2298	5
486	1	2298	8
486	1	2298	19
486	1	2299	19
486	1	2300	0
487	1	2301	1
487	1	2301	2
487	1	2301	4
487	1	2301	6
487	1	2301	7
487	1	2301	8
487	1	2301	11
487	1	2301	14
487	1	2301	21
487	1	2301	23
487	1	2302	1
487	1	2302	2
487	1	2302	23
487	1	2303	2
487	1	2303	23
487	1	2304	23
487	1	2305	0
488	1	2306	2
488	1	2306	3
488	1	2306	10
488	1	2306	12
488	1	2306	13
488	1	2306	17
488	1	2306	19
488	1	2306	23
488	1	2306	24
488	1	2306	25
488	1	2307	2
488	1	2307	3
488	1	2307	10
488	1	2307	24
488	1	2307	25
488	1	2308	0
489	1	2309	2
489	1	2309	5
489	1	2309	6
489	1	2309	8
489	1	2309	14
489	1	2309	15
489	1	2309	16
489	1	2309	20
489	1	2309	21
489	1	2309	23
489	1	2310	2
489	1	2310	8
489	1	2310	14
489	1	2310	15
489	1	2310	21
489	1	2311	2
489	1	2311	8
489	1	2312	8
489	1	2313	0
490	1	2314	3
490	1	2314	4
490	1	2314	5
490	1	2314	6
490	1	2314	10
490	1	2314	12
490	1	2314	16
490	1	2314	18
490	1	2314	21
490	1	2314	22
490	1	2315	4
490	1	2315	5
490	1	2315	6
490	1	2315	10
490	1	2316	0
491	1	2317	4
491	1	2317	8
491	1	2317	10
491	1	2317	11
491	1	2317	12
491	1	2317	13
491	1	2317	18
491	1	2317	19
491	1	2317	22
491	1	2317	24
491	1	2318	4
491	1	2318	10
491	1	2318	12
491	1	2318	22
491	1	2319	4
491	1	2319	10
491	1	2320	4
491	1	2320	10
491	1	2321	4
491	1	2322	4
491	1	2323	0
492	1	2324	4
492	1	2324	6
492	1	2324	7
492	1	2324	12
492	1	2324	15
492	1	2324	18
492	1	2324	21
492	1	2324	22
492	1	2324	23
492	1	2324	24
492	1	2325	12
492	1	2325	15
492	1	2325	22
492	1	2325	24
492	1	2326	15
492	1	2326	24
492	1	2327	24
492	1	2328	24
492	1	2329	0
493	1	2330	1
493	1	2330	3
493	1	2330	6
493	1	2330	7
493	1	2330	9
493	1	2330	17
493	1	2330	19
493	1	2330	21
493	1	2330	24
493	1	2330	25
493	1	2331	1
493	1	2331	6
493	1	2331	17
493	1	2331	19
493	1	2331	21
493	1	2332	19
493	1	2332	21
493	1	2333	21
493	1	2334	0
494	1	2335	1
494	1	2335	8
494	1	2335	10
494	1	2335	11
494	1	2335	12
494	1	2335	14
494	1	2335	17
494	1	2335	18
494	1	2335	20
494	1	2335	23
494	1	2336	8
494	1	2336	23
494	1	2337	23
494	1	2338	23
494	1	2339	0
495	1	2340	1
495	1	2340	3
495	1	2340	4
495	1	2340	6
495	1	2340	10
495	1	2340	15
495	1	2340	16
495	1	2340	19
495	1	2340	21
495	1	2340	24
495	1	2341	1
495	1	2341	3
495	1	2341	6
495	1	2341	10
495	1	2341	16
495	1	2342	6
495	1	2343	6
495	1	2344	0
496	1	2345	1
496	1	2345	2
496	1	2345	4
496	1	2345	5
496	1	2345	8
496	1	2345	13
496	1	2345	15
496	1	2345	18
496	1	2345	21
496	1	2345	22
496	1	2346	2
496	1	2346	13
496	1	2346	15
496	1	2347	0
497	1	2348	3
497	1	2348	4
497	1	2348	6
497	1	2348	7
497	1	2348	10
497	1	2348	12
497	1	2348	16
497	1	2348	18
497	1	2348	21
497	1	2348	25
497	1	2349	3
497	1	2349	4
497	1	2349	7
497	1	2349	25
497	1	2350	0
498	1	2351	2
498	1	2351	11
498	1	2351	13
498	1	2351	16
498	1	2351	17
498	1	2351	18
498	1	2351	19
498	1	2351	21
498	1	2351	22
498	1	2351	25
498	1	2352	2
498	1	2352	13
498	1	2352	19
498	1	2352	21
498	1	2353	19
498	1	2353	21
498	1	2354	0
499	1	2355	1
499	1	2355	7
499	1	2355	13
499	1	2355	14
499	1	2355	15
499	1	2355	16
499	1	2355	17
499	1	2355	22
499	1	2355	23
499	1	2355	24
499	1	2356	1
499	1	2356	14
499	1	2356	15
499	1	2356	17
499	1	2356	23
499	1	2356	24
499	1	2357	15
499	1	2357	17
499	1	2358	0
500	1	2359	1
500	1	2359	2
500	1	2359	8
500	1	2359	9
500	1	2359	10
500	1	2359	11
500	1	2359	13
500	1	2359	16
500	1	2359	18
500	1	2359	25
500	1	2360	1
500	1	2360	2
500	1	2360	9
500	1	2360	10
500	1	2360	16
500	1	2361	1
500	1	2361	2
500	1	2361	9
500	1	2362	2
500	1	2362	9
500	1	2363	9
500	1	2364	0
501	1	2365	1
501	1	2365	3
501	1	2365	4
501	1	2365	5
501	1	2365	6
501	1	2365	10
501	1	2365	12
501	1	2365	13
501	1	2365	19
501	1	2365	24
501	1	2366	4
501	1	2366	6
501	1	2366	12
501	1	2366	24
501	1	2367	4
501	1	2367	6
501	1	2367	24
501	1	2368	6
501	1	2368	24
501	1	2369	6
501	1	2370	6
501	1	2371	0
502	1	2372	3
502	1	2372	6
502	1	2372	9
502	1	2372	10
502	1	2372	12
502	1	2372	16
502	1	2372	17
502	1	2372	18
502	1	2372	23
502	1	2372	25
502	1	2373	9
502	1	2373	12
502	1	2373	16
502	1	2373	18
502	1	2373	23
502	1	2374	12
502	1	2374	18
502	1	2375	0
503	1	2376	3
503	1	2376	5
503	1	2376	7
503	1	2376	10
503	1	2376	11
503	1	2376	12
503	1	2376	13
503	1	2376	18
503	1	2376	20
503	1	2376	25
503	1	2377	7
503	1	2377	11
503	1	2377	13
503	1	2377	25
503	1	2378	7
503	1	2378	11
503	1	2378	13
503	1	2379	13
503	1	2380	0
504	1	2381	3
504	1	2381	4
504	1	2381	6
504	1	2381	7
504	1	2381	12
504	1	2381	13
504	1	2381	16
504	1	2381	17
504	1	2381	21
504	1	2381	22
504	1	2382	12
504	1	2382	13
504	1	2382	16
504	1	2382	17
504	1	2382	22
504	1	2383	17
504	1	2384	17
504	1	2385	0
505	1	2386	1
505	1	2386	4
505	1	2386	5
505	1	2386	9
505	1	2386	11
505	1	2386	19
505	1	2386	20
505	1	2386	21
505	1	2386	22
505	1	2386	25
505	1	2387	1
505	1	2387	11
505	1	2388	1
505	1	2388	11
505	1	2389	1
505	1	2390	0
506	1	2391	1
506	1	2391	2
506	1	2391	7
506	1	2391	10
506	1	2391	13
506	1	2391	15
506	1	2391	16
506	1	2391	17
506	1	2391	20
506	1	2391	23
506	1	2392	7
506	1	2392	10
506	1	2392	15
506	1	2392	20
506	1	2393	7
506	1	2394	0
507	1	2395	3
507	1	2395	4
507	1	2395	8
507	1	2395	9
507	1	2395	11
507	1	2395	12
507	1	2395	16
507	1	2395	21
507	1	2395	22
507	1	2395	24
507	1	2396	8
507	1	2396	9
507	1	2396	11
507	1	2396	21
507	1	2397	8
507	1	2397	11
507	1	2398	8
507	1	2398	11
507	1	2399	8
507	1	2399	11
507	1	2400	8
507	1	2401	8
507	1	2402	8
507	1	2403	0
508	1	2404	6
508	1	2404	8
508	1	2404	9
508	1	2404	13
508	1	2404	16
508	1	2404	17
508	1	2404	18
508	1	2404	19
508	1	2404	20
508	1	2404	21
508	1	2405	13
508	1	2405	16
508	1	2405	20
508	1	2406	13
508	1	2406	16
508	1	2407	13
508	1	2407	16
508	1	2408	0
509	1	2409	3
509	1	2409	4
509	1	2409	11
509	1	2409	13
509	1	2409	14
509	1	2409	15
509	1	2409	17
509	1	2409	18
509	1	2409	23
509	1	2409	24
509	1	2410	11
509	1	2410	15
509	1	2410	18
509	1	2410	24
509	1	2411	11
509	1	2411	15
509	1	2411	18
509	1	2412	0
510	1	2413	2
510	1	2413	10
510	1	2413	11
510	1	2413	13
510	1	2413	14
510	1	2413	17
510	1	2413	19
510	1	2413	22
510	1	2413	23
510	1	2413	24
510	1	2414	2
510	1	2414	14
510	1	2414	22
510	1	2414	23
510	1	2415	0
511	1	2416	1
511	1	2416	2
511	1	2416	3
511	1	2416	8
511	1	2416	9
511	1	2416	10
511	1	2416	12
511	1	2416	19
511	1	2416	23
511	1	2416	24
511	1	2417	2
511	1	2417	3
511	1	2417	12
511	1	2417	19
511	1	2417	24
511	1	2418	2
511	1	2419	0
512	1	2420	2
512	1	2420	4
512	1	2420	6
512	1	2420	7
512	1	2420	8
512	1	2420	16
512	1	2420	17
512	1	2420	19
512	1	2420	20
512	1	2420	23
512	1	2421	2
512	1	2421	8
512	1	2421	23
512	1	2422	23
512	1	2423	23
512	1	2424	0
513	1	2425	2
513	1	2425	7
513	1	2425	8
513	1	2425	9
513	1	2425	12
513	1	2425	14
513	1	2425	16
513	1	2425	17
513	1	2425	18
513	1	2425	23
513	1	2426	12
513	1	2426	14
513	1	2426	16
513	1	2426	17
513	1	2426	18
513	1	2427	12
513	1	2427	14
513	1	2428	14
513	1	2429	0
514	1	2430	2
514	1	2430	3
514	1	2430	6
514	1	2430	9
514	1	2430	13
514	1	2430	15
514	1	2430	16
514	1	2430	22
514	1	2430	24
514	1	2430	25
514	1	2431	2
514	1	2431	3
514	1	2431	15
514	1	2431	16
514	1	2431	24
514	1	2432	2
514	1	2432	16
514	1	2432	24
514	1	2433	2
514	1	2433	16
514	1	2434	2
514	1	2435	0
515	1	2436	1
515	1	2436	5
515	1	2436	7
515	1	2436	10
515	1	2436	11
515	1	2436	13
515	1	2436	18
515	1	2436	22
515	1	2436	24
515	1	2436	25
515	1	2437	5
515	1	2437	22
515	1	2437	24
515	1	2438	0
516	1	2439	1
516	1	2439	3
516	1	2439	4
516	1	2439	6
516	1	2439	12
516	1	2439	14
516	1	2439	18
516	1	2439	19
516	1	2439	22
516	1	2439	24
516	1	2440	1
516	1	2440	12
516	1	2440	19
516	1	2441	12
516	1	2441	19
516	1	2442	0
517	1	2443	1
517	1	2443	4
517	1	2443	8
517	1	2443	11
517	1	2443	12
517	1	2443	13
517	1	2443	18
517	1	2443	19
517	1	2443	24
517	1	2443	25
517	1	2444	1
517	1	2444	13
517	1	2444	24
517	1	2445	24
517	1	2446	0
518	1	2447	1
518	1	2447	6
518	1	2447	7
518	1	2447	9
518	1	2447	10
518	1	2447	11
518	1	2447	12
518	1	2447	21
518	1	2447	24
518	1	2447	25
518	1	2448	1
518	1	2448	7
518	1	2448	10
518	1	2448	21
518	1	2448	25
518	1	2449	7
518	1	2449	10
518	1	2449	25
518	1	2450	10
518	1	2451	0
519	1	2452	2
519	1	2452	3
519	1	2452	4
519	1	2452	5
519	1	2452	10
519	1	2452	12
519	1	2452	13
519	1	2452	14
519	1	2452	16
519	1	2452	19
519	1	2453	2
519	1	2453	3
519	1	2453	14
519	1	2454	3
519	1	2454	14
519	1	2455	0
520	1	2456	1
520	1	2456	2
520	1	2456	3
520	1	2456	7
520	1	2456	11
520	1	2456	15
520	1	2456	16
520	1	2456	20
520	1	2456	22
520	1	2456	23
520	1	2457	2
520	1	2457	7
520	1	2458	7
520	1	2459	7
520	1	2460	7
520	1	2461	0
521	1	2462	1
521	1	2462	2
521	1	2462	6
521	1	2462	7
521	1	2462	8
521	1	2462	13
521	1	2462	19
521	1	2462	21
521	1	2462	23
521	1	2462	24
521	1	2463	1
521	1	2463	2
521	1	2463	6
521	1	2463	8
521	1	2463	19
521	1	2463	24
521	1	2464	2
521	1	2464	8
521	1	2464	19
521	1	2465	0
522	1	2466	3
522	1	2466	4
522	1	2466	6
522	1	2466	10
522	1	2466	11
522	1	2466	15
522	1	2466	16
522	1	2466	18
522	1	2466	22
522	1	2466	23
522	1	2467	3
522	1	2467	4
522	1	2468	0
523	1	2469	3
523	1	2469	8
523	1	2469	9
523	1	2469	10
523	1	2469	12
523	1	2469	14
523	1	2469	15
523	1	2469	16
523	1	2469	22
523	1	2469	23
523	1	2470	8
523	1	2470	14
523	1	2470	15
523	1	2470	16
523	1	2471	15
523	1	2471	16
523	1	2472	0
524	1	2473	2
524	1	2473	3
524	1	2473	5
524	1	2473	11
524	1	2473	12
524	1	2473	13
524	1	2473	15
524	1	2473	17
524	1	2473	22
524	1	2473	24
524	1	2474	3
524	1	2474	12
524	1	2474	13
524	1	2474	22
524	1	2475	12
524	1	2476	0
525	1	2477	4
525	1	2477	6
525	1	2477	11
525	1	2477	12
525	1	2477	16
525	1	2477	17
525	1	2477	21
525	1	2477	22
525	1	2477	23
525	1	2477	25
525	1	2478	4
525	1	2478	6
525	1	2478	17
525	1	2479	6
525	1	2480	0
526	1	2481	1
526	1	2481	4
526	1	2481	8
526	1	2481	11
526	1	2481	12
526	1	2481	16
526	1	2481	19
526	1	2481	22
526	1	2481	23
526	1	2481	24
526	1	2482	1
526	1	2482	4
526	1	2482	8
526	1	2482	19
526	1	2482	22
526	1	2482	23
526	1	2483	1
526	1	2483	4
526	1	2484	1
526	1	2485	0
527	1	2486	3
527	1	2486	6
527	1	2486	7
527	1	2486	13
527	1	2486	14
527	1	2486	15
527	1	2486	16
527	1	2486	17
527	1	2486	21
527	1	2486	22
527	1	2487	3
527	1	2487	7
527	1	2487	15
527	1	2487	17
527	1	2487	21
527	1	2488	3
527	1	2488	15
527	1	2488	17
527	1	2489	3
527	1	2489	15
527	1	2489	17
527	1	2490	17
527	1	2491	0
528	1	2492	1
528	1	2492	2
528	1	2492	3
528	1	2492	5
528	1	2492	6
528	1	2492	16
528	1	2492	18
528	1	2492	19
528	1	2492	21
528	1	2492	25
528	1	2493	1
528	1	2493	5
528	1	2493	19
528	1	2494	19
528	1	2495	0
529	1	2496	1
529	1	2496	5
529	1	2496	6
529	1	2496	7
529	1	2496	12
529	1	2496	14
529	1	2496	15
529	1	2496	16
529	1	2496	19
529	1	2496	21
529	1	2497	1
529	1	2497	5
529	1	2497	16
529	1	2497	21
529	1	2498	16
529	1	2498	21
529	1	2499	21
529	1	2500	0
530	1	2501	10
530	1	2501	12
530	1	2501	13
530	1	2501	14
530	1	2501	15
530	1	2501	16
530	1	2501	17
530	1	2501	18
530	1	2501	21
530	1	2501	24
530	1	2502	10
530	1	2502	14
530	1	2502	16
530	1	2502	17
530	1	2503	14
530	1	2503	16
530	1	2503	17
530	1	2504	0
531	1	2505	5
531	1	2505	7
531	1	2505	11
531	1	2505	12
531	1	2505	13
531	1	2505	14
531	1	2505	15
531	1	2505	16
531	1	2505	20
531	1	2505	22
531	1	2506	7
531	1	2506	12
531	1	2506	13
531	1	2507	12
531	1	2508	0
532	1	2509	1
532	1	2509	6
532	1	2509	7
532	1	2509	8
532	1	2509	15
532	1	2509	16
532	1	2509	17
532	1	2509	18
532	1	2509	20
532	1	2509	24
532	1	2510	6
532	1	2510	8
532	1	2510	15
532	1	2510	18
532	1	2511	0
533	1	2512	4
533	1	2512	5
533	1	2512	6
533	1	2512	8
533	1	2512	11
533	1	2512	13
533	1	2512	17
533	1	2512	22
533	1	2512	24
533	1	2512	25
533	1	2513	5
533	1	2513	8
533	1	2513	13
533	1	2513	22
533	1	2513	25
533	1	2514	13
533	1	2514	22
533	1	2514	25
533	1	2515	13
533	1	2516	13
533	1	2517	13
533	1	2518	0
534	1	2519	1
534	1	2519	6
534	1	2519	7
534	1	2519	9
534	1	2519	15
534	1	2519	16
534	1	2519	17
534	1	2519	20
534	1	2519	21
534	1	2519	23
534	1	2520	9
534	1	2520	17
534	1	2520	20
534	1	2520	21
534	1	2521	9
534	1	2521	20
534	1	2522	20
534	1	2523	0
535	1	2524	4
535	1	2524	8
535	1	2524	9
535	1	2524	10
535	1	2524	11
535	1	2524	13
535	1	2524	17
535	1	2524	18
535	1	2524	21
535	1	2524	22
535	1	2525	8
535	1	2525	9
535	1	2525	22
535	1	2526	9
535	1	2527	0
536	1	2528	1
536	1	2528	4
536	1	2528	6
536	1	2528	14
536	1	2528	16
536	1	2528	17
536	1	2528	18
536	1	2528	19
536	1	2528	21
536	1	2528	25
536	1	2529	1
536	1	2529	4
536	1	2529	17
536	1	2529	19
536	1	2530	17
536	1	2530	19
536	1	2531	19
536	1	2532	19
536	1	2533	0
537	1	2534	1
537	1	2534	2
537	1	2534	3
537	1	2534	4
537	1	2534	5
537	1	2534	6
537	1	2534	9
537	1	2534	13
537	1	2534	19
537	1	2534	24
537	1	2535	1
537	1	2535	2
537	1	2535	3
537	1	2535	4
537	1	2535	9
537	1	2535	19
537	1	2536	3
537	1	2537	3
537	1	2538	3
537	1	2539	0
538	1	2540	2
538	1	2540	4
538	1	2540	9
538	1	2540	10
538	1	2540	13
538	1	2540	15
538	1	2540	16
538	1	2540	17
538	1	2540	19
538	1	2540	25
538	1	2541	9
538	1	2541	10
538	1	2541	15
538	1	2542	9
538	1	2543	0
539	1	2544	1
539	1	2544	2
539	1	2544	4
539	1	2544	9
539	1	2544	14
539	1	2544	16
539	1	2544	17
539	1	2544	19
539	1	2544	22
539	1	2544	25
539	1	2545	4
539	1	2545	17
539	1	2545	22
539	1	2545	25
539	1	2546	0
540	1	2547	3
540	1	2547	4
540	1	2547	6
540	1	2547	7
540	1	2547	8
540	1	2547	11
540	1	2547	13
540	1	2547	14
540	1	2547	17
540	1	2547	20
540	1	2548	6
540	1	2548	7
540	1	2548	14
540	1	2548	17
540	1	2548	20
540	1	2549	14
540	1	2549	20
540	1	2550	14
540	1	2551	0
541	1	2552	2
541	1	2552	6
541	1	2552	7
541	1	2552	8
541	1	2552	11
541	1	2552	16
541	1	2552	19
541	1	2552	20
541	1	2552	22
541	1	2552	23
541	1	2553	6
541	1	2553	16
541	1	2553	20
541	1	2553	22
541	1	2553	23
541	1	2554	6
541	1	2554	23
541	1	2555	0
542	1	2556	3
542	1	2556	4
542	1	2556	6
542	1	2556	7
542	1	2556	8
542	1	2556	9
542	1	2556	13
542	1	2556	14
542	1	2556	16
542	1	2556	19
542	1	2557	13
542	1	2557	14
542	1	2557	16
542	1	2557	19
542	1	2558	13
542	1	2558	19
542	1	2559	0
543	1	2560	3
543	1	2560	7
543	1	2560	10
543	1	2560	12
543	1	2560	13
543	1	2560	15
543	1	2560	17
543	1	2560	19
543	1	2560	21
543	1	2560	22
543	1	2561	10
543	1	2561	19
543	1	2561	22
543	1	2562	19
543	1	2563	0
544	1	2564	1
544	1	2564	3
544	1	2564	5
544	1	2564	9
544	1	2564	10
544	1	2564	12
544	1	2564	13
544	1	2564	14
544	1	2564	19
544	1	2564	20
544	1	2565	3
544	1	2565	13
544	1	2565	19
544	1	2566	3
544	1	2567	0
545	1	2568	3
545	1	2568	5
545	1	2568	7
545	1	2568	10
545	1	2568	13
545	1	2568	16
545	1	2568	18
545	1	2568	19
545	1	2568	23
545	1	2568	25
545	1	2569	7
545	1	2569	10
545	1	2570	0
546	1	2571	1
546	1	2571	3
546	1	2571	6
546	1	2571	8
546	1	2571	9
546	1	2571	11
546	1	2571	12
546	1	2571	13
546	1	2571	18
546	1	2571	22
546	1	2572	6
546	1	2572	18
546	1	2572	22
546	1	2573	0
547	1	2574	4
547	1	2574	5
547	1	2574	6
547	1	2574	8
547	1	2574	13
547	1	2574	15
547	1	2574	18
547	1	2574	22
547	1	2574	23
547	1	2574	24
547	1	2575	4
547	1	2575	13
547	1	2575	18
547	1	2575	22
547	1	2575	24
547	1	2576	4
547	1	2576	22
547	1	2577	22
547	1	2578	0
548	1	2579	2
548	1	2579	5
548	1	2579	6
548	1	2579	9
548	1	2579	11
548	1	2579	13
548	1	2579	14
548	1	2579	20
548	1	2579	21
548	1	2579	24
548	1	2580	2
548	1	2580	6
548	1	2580	9
548	1	2580	21
548	1	2580	24
548	1	2581	6
548	1	2581	9
548	1	2581	24
548	1	2582	6
548	1	2582	9
548	1	2583	6
548	1	2583	9
548	1	2584	6
548	1	2584	9
548	1	2585	9
548	1	2586	9
548	1	2587	0
549	1	2588	1
549	1	2588	2
549	1	2588	6
549	1	2588	7
549	1	2588	11
549	1	2588	12
549	1	2588	13
549	1	2588	16
549	1	2588	19
549	1	2588	20
549	1	2589	6
549	1	2589	11
549	1	2589	12
549	1	2589	13
549	1	2589	16
549	1	2589	19
549	1	2589	20
549	1	2590	6
549	1	2590	11
549	1	2590	12
549	1	2590	19
549	1	2591	6
549	1	2591	19
549	1	2592	0
550	1	2593	2
550	1	2593	3
550	1	2593	4
550	1	2593	7
550	1	2593	11
550	1	2593	14
550	1	2593	16
550	1	2593	18
550	1	2593	19
550	1	2593	25
550	1	2594	2
550	1	2594	3
550	1	2594	7
550	1	2594	19
550	1	2595	7
550	1	2595	19
550	1	2596	7
550	1	2597	0
551	1	2598	2
551	1	2598	4
551	1	2598	5
551	1	2598	7
551	1	2598	8
551	1	2598	15
551	1	2598	16
551	1	2598	21
551	1	2598	22
551	1	2598	24
551	1	2599	5
551	1	2599	7
551	1	2599	15
551	1	2599	16
551	1	2599	21
551	1	2599	24
551	1	2600	21
551	1	2601	0
552	1	2602	7
552	1	2602	9
552	1	2602	13
552	1	2602	14
552	1	2602	15
552	1	2602	17
552	1	2602	21
552	1	2602	22
552	1	2602	24
552	1	2602	25
552	1	2603	14
552	1	2603	22
552	1	2604	0
553	1	2605	3
553	1	2605	4
553	1	2605	6
553	1	2605	8
553	1	2605	10
553	1	2605	13
553	1	2605	14
553	1	2605	17
553	1	2605	18
553	1	2605	20
553	1	2606	4
553	1	2606	13
553	1	2606	17
553	1	2607	4
553	1	2607	13
553	1	2608	13
553	1	2609	13
553	1	2610	13
553	1	2611	0
554	1	2612	2
554	1	2612	4
554	1	2612	5
554	1	2612	7
554	1	2612	8
554	1	2612	12
554	1	2612	14
554	1	2612	15
554	1	2612	22
554	1	2612	24
554	1	2613	4
554	1	2613	7
554	1	2613	12
554	1	2613	22
554	1	2613	24
554	1	2614	7
554	1	2614	12
554	1	2614	22
554	1	2615	7
554	1	2615	12
554	1	2616	0
555	1	2617	2
555	1	2617	4
555	1	2617	9
555	1	2617	14
555	1	2617	15
555	1	2617	16
555	1	2617	19
555	1	2617	20
555	1	2617	21
555	1	2617	23
555	1	2618	14
555	1	2618	15
555	1	2618	21
555	1	2618	23
555	1	2619	14
555	1	2619	21
555	1	2619	23
555	1	2620	21
555	1	2621	21
555	1	2622	21
555	1	2623	21
555	1	2624	0
556	1	2625	1
556	1	2625	2
556	1	2625	6
556	1	2625	14
556	1	2625	15
556	1	2625	16
556	1	2625	17
556	1	2625	22
556	1	2625	23
556	1	2625	24
556	1	2626	1
556	1	2626	2
556	1	2626	15
556	1	2626	16
556	1	2627	2
556	1	2627	15
556	1	2628	2
556	1	2629	0
557	1	2630	4
557	1	2630	5
557	1	2630	7
557	1	2630	11
557	1	2630	12
557	1	2630	15
557	1	2630	18
557	1	2630	19
557	1	2630	23
557	1	2630	24
557	1	2631	12
557	1	2631	15
557	1	2632	0
558	1	2633	2
558	1	2633	5
558	1	2633	7
558	1	2633	8
558	1	2633	10
558	1	2633	13
558	1	2633	20
558	1	2633	21
558	1	2633	22
558	1	2633	23
558	1	2634	5
558	1	2634	8
558	1	2634	13
558	1	2634	23
558	1	2635	0
559	1	2636	2
559	1	2636	6
559	1	2636	12
559	1	2636	14
559	1	2636	16
559	1	2636	17
559	1	2636	19
559	1	2636	20
559	1	2636	21
559	1	2636	23
559	1	2637	6
559	1	2637	14
559	1	2637	16
559	1	2637	17
559	1	2638	6
559	1	2638	16
559	1	2638	17
559	1	2639	6
559	1	2639	17
559	1	2640	17
559	1	2641	0
560	1	2642	1
560	1	2642	3
560	1	2642	6
560	1	2642	7
560	1	2642	10
560	1	2642	11
560	1	2642	12
560	1	2642	18
560	1	2642	23
560	1	2642	25
560	1	2643	7
560	1	2643	10
560	1	2643	23
560	1	2644	7
560	1	2644	23
560	1	2645	23
560	1	2646	0
561	1	2647	2
561	1	2647	7
561	1	2647	8
561	1	2647	11
561	1	2647	12
561	1	2647	14
561	1	2647	15
561	1	2647	20
561	1	2647	21
561	1	2647	23
561	1	2648	2
561	1	2648	21
561	1	2648	23
561	1	2649	21
561	1	2650	21
561	1	2651	21
561	1	2652	21
561	1	2653	0
562	1	2654	2
562	1	2654	4
562	1	2654	7
562	1	2654	8
562	1	2654	11
562	1	2654	12
562	1	2654	14
562	1	2654	18
562	1	2654	22
562	1	2654	23
562	1	2655	2
562	1	2655	4
562	1	2655	7
562	1	2655	12
562	1	2655	18
562	1	2656	0
563	1	2657	4
563	1	2657	9
563	1	2657	11
563	1	2657	14
563	1	2657	18
563	1	2657	19
563	1	2657	20
563	1	2657	22
563	1	2657	23
563	1	2657	25
563	1	2658	11
563	1	2658	19
563	1	2658	20
563	1	2658	22
563	1	2658	23
563	1	2658	25
563	1	2659	25
563	1	2660	0
564	1	2661	2
564	1	2661	7
564	1	2661	11
564	1	2661	13
564	1	2661	14
564	1	2661	19
564	1	2661	20
564	1	2661	21
564	1	2661	23
564	1	2661	24
564	1	2662	2
564	1	2662	7
564	1	2662	11
564	1	2662	21
564	1	2662	24
564	1	2663	2
564	1	2663	24
564	1	2664	2
564	1	2665	2
564	1	2666	0
565	1	2667	5
565	1	2667	6
565	1	2667	7
565	1	2667	12
565	1	2667	14
565	1	2667	16
565	1	2667	17
565	1	2667	18
565	1	2667	21
565	1	2667	22
565	1	2668	6
565	1	2668	7
565	1	2668	12
565	1	2668	14
565	1	2668	21
565	1	2669	12
565	1	2670	12
565	1	2671	0
566	1	2672	1
566	1	2672	4
566	1	2672	7
566	1	2672	8
566	1	2672	12
566	1	2672	14
566	1	2672	18
566	1	2672	20
566	1	2672	23
566	1	2672	25
566	1	2673	1
566	1	2673	18
566	1	2673	25
566	1	2674	18
566	1	2675	0
567	1	2676	1
567	1	2676	3
567	1	2676	4
567	1	2676	5
567	1	2676	7
567	1	2676	10
567	1	2676	12
567	1	2676	17
567	1	2676	20
567	1	2676	24
567	1	2677	5
567	1	2677	7
567	1	2677	20
567	1	2678	0
568	1	2679	1
568	1	2679	2
568	1	2679	3
568	1	2679	11
568	1	2679	14
568	1	2679	15
568	1	2679	17
568	1	2679	18
568	1	2679	21
568	1	2679	23
568	1	2680	3
568	1	2680	14
568	1	2680	18
568	1	2680	21
568	1	2681	3
568	1	2682	0
569	1	2683	5
569	1	2683	6
569	1	2683	7
569	1	2683	9
569	1	2683	15
569	1	2683	16
569	1	2683	17
569	1	2683	18
569	1	2683	19
569	1	2683	24
569	1	2684	5
569	1	2684	16
569	1	2684	17
569	1	2684	18
569	1	2684	19
569	1	2684	24
569	1	2685	19
569	1	2686	0
570	1	2687	1
570	1	2687	2
570	1	2687	8
570	1	2687	9
570	1	2687	12
570	1	2687	17
570	1	2687	18
570	1	2687	23
570	1	2687	24
570	1	2687	25
570	1	2688	1
570	1	2688	9
570	1	2688	12
570	1	2688	23
570	1	2688	24
570	1	2689	1
570	1	2689	12
570	1	2690	0
571	1	2691	3
571	1	2691	4
571	1	2691	5
571	1	2691	7
571	1	2691	8
571	1	2691	14
571	1	2691	16
571	1	2691	20
571	1	2691	22
571	1	2691	23
571	1	2692	5
571	1	2692	7
571	1	2692	16
571	1	2692	23
571	1	2693	5
571	1	2693	23
571	1	2694	0
572	1	2695	3
572	1	2695	4
572	1	2695	5
572	1	2695	6
572	1	2695	7
572	1	2695	14
572	1	2695	16
572	1	2695	18
572	1	2695	19
572	1	2695	22
572	1	2696	5
572	1	2696	19
572	1	2697	0
573	1	2698	6
573	1	2698	7
573	1	2698	11
573	1	2698	13
573	1	2698	14
573	1	2698	15
573	1	2698	16
573	1	2698	18
573	1	2698	19
573	1	2698	21
573	1	2699	18
573	1	2699	19
573	1	2699	21
573	1	2700	18
573	1	2701	0
574	1	2702	3
574	1	2702	5
574	1	2702	8
574	1	2702	9
574	1	2702	11
574	1	2702	12
574	1	2702	13
574	1	2702	20
574	1	2702	22
574	1	2702	24
574	1	2703	3
574	1	2703	8
574	1	2703	11
574	1	2703	22
574	1	2704	3
574	1	2704	22
574	1	2705	0
575	1	2706	2
575	1	2706	5
575	1	2706	6
575	1	2706	14
575	1	2706	16
575	1	2706	17
575	1	2706	19
575	1	2706	20
575	1	2706	23
575	1	2706	24
575	1	2707	6
575	1	2707	19
575	1	2707	20
575	1	2707	23
575	1	2707	24
575	1	2708	20
575	1	2709	20
575	1	2710	0
576	1	2711	2
576	1	2711	5
576	1	2711	6
576	1	2711	7
576	1	2711	9
576	1	2711	10
576	1	2711	13
576	1	2711	14
576	1	2711	17
576	1	2711	21
576	1	2712	5
576	1	2712	6
576	1	2712	7
576	1	2712	9
576	1	2712	10
576	1	2712	14
576	1	2712	21
576	1	2713	10
576	1	2713	14
576	1	2714	10
576	1	2714	14
576	1	2715	10
576	1	2716	0
577	1	2717	1
577	1	2717	6
577	1	2717	7
577	1	2717	8
577	1	2717	12
577	1	2717	13
577	1	2717	18
577	1	2717	19
577	1	2717	23
577	1	2717	25
577	1	2718	13
577	1	2718	18
577	1	2719	18
577	1	2720	18
577	1	2721	0
578	1	2722	7
578	1	2722	9
578	1	2722	10
578	1	2722	11
578	1	2722	13
578	1	2722	14
578	1	2722	15
578	1	2722	16
578	1	2722	17
578	1	2722	19
578	1	2723	9
578	1	2723	11
578	1	2723	13
578	1	2723	14
578	1	2723	16
578	1	2723	19
578	1	2724	9
578	1	2724	11
578	1	2724	16
578	1	2725	16
578	1	2726	0
579	1	2727	1
579	1	2727	5
579	1	2727	6
579	1	2727	7
579	1	2727	14
579	1	2727	15
579	1	2727	21
579	1	2727	22
579	1	2727	24
579	1	2727	25
579	1	2728	6
579	1	2728	7
579	1	2728	15
579	1	2728	21
579	1	2728	24
579	1	2728	25
579	1	2729	7
579	1	2729	15
579	1	2729	24
579	1	2730	0
580	1	2731	2
580	1	2731	4
580	1	2731	5
580	1	2731	6
580	1	2731	10
580	1	2731	15
580	1	2731	16
580	1	2731	17
580	1	2731	22
580	1	2731	24
580	1	2732	4
580	1	2732	17
580	1	2732	22
580	1	2733	17
580	1	2734	0
581	1	2735	3
581	1	2735	7
581	1	2735	10
581	1	2735	13
581	1	2735	15
581	1	2735	16
581	1	2735	19
581	1	2735	20
581	1	2735	22
581	1	2735	25
581	1	2736	7
581	1	2736	10
581	1	2736	13
581	1	2736	16
581	1	2736	22
581	1	2737	13
581	1	2737	22
581	1	2738	22
581	1	2739	0
582	1	2740	1
582	1	2740	4
582	1	2740	12
582	1	2740	16
582	1	2740	18
582	1	2740	20
582	1	2740	21
582	1	2740	22
582	1	2740	24
582	1	2740	25
582	1	2741	12
582	1	2741	16
582	1	2741	20
582	1	2741	21
582	1	2742	16
582	1	2742	21
582	1	2743	21
582	1	2744	0
583	1	2745	2
583	1	2745	3
583	1	2745	4
583	1	2745	5
583	1	2745	8
583	1	2745	13
583	1	2745	16
583	1	2745	18
583	1	2745	20
583	1	2745	21
583	1	2746	2
583	1	2746	5
583	1	2746	8
583	1	2746	16
583	1	2746	20
583	1	2746	21
583	1	2747	16
583	1	2748	0
584	1	2749	1
584	1	2749	3
584	1	2749	4
584	1	2749	8
584	1	2749	11
584	1	2749	15
584	1	2749	17
584	1	2749	19
584	1	2749	23
584	1	2749	25
584	1	2750	3
584	1	2750	4
584	1	2750	15
584	1	2750	19
584	1	2750	25
584	1	2751	4
584	1	2752	0
585	1	2753	1
585	1	2753	3
585	1	2753	4
585	1	2753	6
585	1	2753	9
585	1	2753	10
585	1	2753	13
585	1	2753	15
585	1	2753	19
585	1	2753	23
585	1	2754	1
585	1	2754	6
585	1	2754	15
585	1	2754	23
585	1	2755	6
585	1	2756	0
586	1	2757	2
586	1	2757	4
586	1	2757	11
586	1	2757	14
586	1	2757	15
586	1	2757	16
586	1	2757	20
586	1	2757	21
586	1	2757	22
586	1	2757	24
586	1	2758	14
586	1	2758	15
586	1	2758	20
586	1	2759	14
586	1	2760	0
587	1	2761	5
587	1	2761	6
587	1	2761	7
587	1	2761	9
587	1	2761	10
587	1	2761	12
587	1	2761	16
587	1	2761	23
587	1	2761	24
587	1	2761	25
587	1	2762	7
587	1	2762	25
587	1	2763	7
587	1	2763	25
587	1	2764	0
588	1	2765	1
588	1	2765	4
588	1	2765	8
588	1	2765	9
588	1	2765	10
588	1	2765	12
588	1	2765	13
588	1	2765	17
588	1	2765	18
588	1	2765	22
588	1	2766	10
588	1	2766	12
588	1	2766	13
588	1	2766	18
588	1	2767	10
588	1	2767	12
588	1	2767	13
588	1	2768	10
588	1	2768	12
588	1	2769	0
589	1	2770	1
589	1	2770	5
589	1	2770	7
589	1	2770	9
589	1	2770	14
589	1	2770	16
589	1	2770	17
589	1	2770	22
589	1	2770	24
589	1	2770	25
589	1	2771	1
589	1	2771	5
589	1	2771	14
589	1	2771	24
589	1	2772	14
589	1	2773	0
590	1	2774	3
590	1	2774	5
590	1	2774	7
590	1	2774	9
590	1	2774	10
590	1	2774	11
590	1	2774	14
590	1	2774	16
590	1	2774	17
590	1	2774	19
590	1	2775	5
590	1	2775	7
590	1	2775	9
590	1	2775	10
590	1	2775	11
590	1	2775	16
590	1	2775	17
590	1	2776	7
590	1	2776	9
590	1	2776	10
590	1	2776	11
590	1	2776	16
590	1	2777	10
590	1	2777	16
590	1	2778	16
590	1	2779	16
590	1	2780	16
590	1	2781	0
591	1	2782	2
591	1	2782	3
591	1	2782	5
591	1	2782	7
591	1	2782	8
591	1	2782	13
591	1	2782	14
591	1	2782	15
591	1	2782	21
591	1	2782	25
591	1	2783	3
591	1	2783	5
591	1	2783	14
591	1	2784	5
591	1	2785	0
592	1	2786	4
592	1	2786	8
592	1	2786	9
592	1	2786	11
592	1	2786	13
592	1	2786	14
592	1	2786	19
592	1	2786	20
592	1	2786	22
592	1	2786	24
592	1	2787	8
592	1	2787	13
592	1	2787	20
592	1	2788	13
592	1	2789	0
593	1	2790	1
593	1	2790	4
593	1	2790	6
593	1	2790	14
593	1	2790	15
593	1	2790	17
593	1	2790	18
593	1	2790	19
593	1	2790	23
593	1	2790	24
593	1	2791	1
593	1	2791	18
593	1	2791	19
593	1	2792	19
593	1	2793	19
593	1	2794	19
593	1	2795	0
594	1	2796	2
594	1	2796	5
594	1	2796	6
594	1	2796	8
594	1	2796	11
594	1	2796	13
594	1	2796	14
1	1	1	1
1	1	1	4
1	1	1	7
1	1	1	8
1	1	1	12
1	1	1	15
1	1	1	17
1	1	1	19
1	1	1	21
1	1	1	22
1	1	2	8
1	1	2	17
1	1	2	21
1	1	2	22
1	1	3	21
1	1	3	22
1	1	4	21
1	1	4	22
1	1	5	21
1	1	5	22
1	1	6	22
1	1	7	0
2	1	8	2
2	1	8	3
2	1	8	4
2	1	8	7
2	1	8	11
2	1	8	12
2	1	8	14
2	1	8	21
2	1	8	23
2	1	8	24
2	1	9	2
2	1	9	7
2	1	9	12
2	1	9	14
2	1	9	23
2	1	10	7
2	1	11	0
3	1	12	3
3	1	12	6
3	1	12	13
3	1	12	15
3	1	12	18
3	1	12	19
3	1	12	20
3	1	12	21
3	1	12	22
3	1	12	23
3	1	13	18
3	1	13	20
3	1	13	21
3	1	13	22
3	1	14	22
3	1	15	22
3	1	16	22
3	1	17	22
3	1	18	0
4	1	19	1
4	1	19	3
4	1	19	4
4	1	19	9
4	1	19	12
4	1	19	18
4	1	19	19
4	1	19	21
4	1	19	22
4	1	19	25
4	1	20	1
4	1	20	12
4	1	20	21
4	1	20	22
4	1	20	25
4	1	21	12
4	1	21	21
4	1	22	21
4	1	23	21
4	1	24	0
5	1	25	8
5	1	25	10
5	1	25	11
5	1	25	12
5	1	25	15
5	1	25	17
5	1	25	18
5	1	25	19
5	1	25	21
5	1	25	25
5	1	26	12
5	1	26	15
5	1	26	18
5	1	26	25
5	1	27	0
6	1	28	2
6	1	28	4
6	1	28	5
6	1	28	6
6	1	28	8
6	1	28	15
6	1	28	22
6	1	28	23
6	1	28	24
6	1	28	25
6	1	29	2
6	1	29	15
6	1	29	23
6	1	29	25
6	1	30	15
6	1	30	25
6	1	31	0
7	1	32	3
7	1	32	5
7	1	32	8
7	1	32	12
7	1	32	13
7	1	32	18
7	1	32	19
7	1	32	21
7	1	32	24
7	1	32	25
7	1	33	3
7	1	33	13
7	1	33	18
7	1	33	25
7	1	34	3
7	1	34	13
7	1	34	25
7	1	35	3
7	1	36	3
7	1	37	0
8	1	38	4
8	1	38	5
8	1	38	11
8	1	38	12
8	1	38	17
8	1	38	18
8	1	38	19
8	1	38	20
8	1	38	21
8	1	38	23
8	1	39	4
8	1	39	5
8	1	39	12
8	1	39	20
8	1	40	4
8	1	41	0
9	1	42	2
9	1	42	7
9	1	42	9
9	1	42	10
9	1	42	13
9	1	42	16
9	1	42	18
9	1	42	19
9	1	42	20
9	1	42	23
9	1	43	2
9	1	43	13
9	1	43	16
9	1	44	2
9	1	44	16
9	1	45	0
10	1	46	3
10	1	46	7
10	1	46	9
10	1	46	12
10	1	46	13
10	1	46	15
10	1	46	16
10	1	46	17
10	1	46	20
10	1	46	22
10	1	47	7
10	1	47	9
10	1	47	12
10	1	47	16
10	1	47	17
10	1	48	9
10	1	48	12
10	1	49	9
10	1	49	12
10	1	50	0
11	1	51	2
11	1	51	4
11	1	51	9
11	1	51	10
11	1	51	12
11	1	51	15
11	1	51	18
11	1	51	19
11	1	51	24
11	1	51	25
11	1	52	10
11	1	52	18
11	1	52	19
11	1	53	10
11	1	54	10
11	1	55	10
11	1	56	10
11	1	57	10
11	1	58	10
11	1	59	0
12	1	60	6
12	1	60	7
12	1	60	9
12	1	60	10
12	1	60	12
12	1	60	13
12	1	60	14
12	1	60	15
12	1	60	20
12	1	60	21
12	1	61	6
12	1	61	7
12	1	61	10
12	1	61	21
12	1	62	6
12	1	62	10
12	1	62	21
12	1	63	6
12	1	64	0
13	1	65	3
13	1	65	5
13	1	65	6
13	1	65	8
13	1	65	9
13	1	65	11
13	1	65	12
13	1	65	13
13	1	65	14
13	1	65	24
13	1	66	3
13	1	66	5
13	1	66	6
13	1	66	9
13	1	66	12
13	1	66	13
13	1	67	3
13	1	67	6
13	1	68	0
14	1	69	2
14	1	69	3
14	1	69	5
14	1	69	6
14	1	69	12
14	1	69	13
14	1	69	14
14	1	69	16
14	1	69	22
14	1	69	25
14	1	70	13
14	1	70	22
14	1	71	0
15	1	72	3
15	1	72	4
15	1	72	6
15	1	72	9
15	1	72	10
15	1	72	14
15	1	72	19
15	1	72	20
15	1	72	21
15	1	72	22
15	1	73	3
15	1	73	4
15	1	73	6
15	1	73	9
15	1	73	20
15	1	73	22
15	1	74	9
15	1	74	20
15	1	75	9
15	1	76	0
16	1	77	1
16	1	77	5
16	1	77	7
16	1	77	10
16	1	77	12
16	1	77	13
16	1	77	15
16	1	77	16
16	1	77	19
16	1	77	23
16	1	78	10
16	1	78	19
16	1	79	10
16	1	79	19
16	1	80	19
16	1	81	0
17	1	82	2
17	1	82	3
17	1	82	7
17	1	82	10
17	1	82	11
17	1	82	14
17	1	82	16
17	1	82	21
17	1	82	24
17	1	82	25
17	1	83	7
17	1	83	16
17	1	83	21
17	1	84	7
17	1	84	21
17	1	85	0
18	1	86	1
18	1	86	3
18	1	86	7
18	1	86	10
18	1	86	11
18	1	86	15
18	1	86	16
18	1	86	20
18	1	86	21
18	1	86	22
18	1	87	7
18	1	87	16
18	1	87	21
18	1	88	7
18	1	88	16
18	1	88	21
18	1	89	7
18	1	90	7
18	1	91	7
18	1	92	7
18	1	93	0
19	1	94	1
19	1	94	3
19	1	94	5
19	1	94	6
19	1	94	7
19	1	94	10
19	1	94	14
19	1	94	19
19	1	94	20
19	1	94	25
19	1	95	6
19	1	95	7
19	1	95	25
19	1	96	7
19	1	96	25
19	1	97	7
19	1	98	7
19	1	99	0
20	1	100	2
20	1	100	5
20	1	100	6
20	1	100	7
20	1	100	15
20	1	100	18
20	1	100	19
20	1	100	20
20	1	100	21
20	1	100	24
20	1	101	2
20	1	101	5
20	1	101	15
20	1	101	18
20	1	102	5
20	1	102	15
20	1	103	15
20	1	104	0
21	1	105	1
21	1	105	2
21	1	105	3
21	1	105	5
21	1	105	14
21	1	105	16
21	1	105	18
21	1	105	20
21	1	105	23
21	1	105	24
21	1	106	16
21	1	106	18
21	1	106	20
21	1	106	24
21	1	107	16
21	1	107	20
21	1	108	20
21	1	109	0
22	1	110	2
22	1	110	7
22	1	110	8
22	1	110	9
22	1	110	10
22	1	110	11
22	1	110	15
22	1	110	16
22	1	110	18
22	1	110	24
22	1	111	2
22	1	111	7
22	1	111	8
22	1	111	9
22	1	111	16
22	1	112	7
22	1	112	8
22	1	112	9
22	1	112	16
22	1	113	7
22	1	113	9
22	1	113	16
22	1	114	16
22	1	115	0
23	1	116	3
23	1	116	4
23	1	116	5
23	1	116	6
23	1	116	7
23	1	116	8
23	1	116	15
23	1	116	17
23	1	116	22
23	1	116	24
23	1	117	3
23	1	117	4
23	1	117	8
23	1	117	22
23	1	117	24
23	1	118	3
23	1	119	3
23	1	120	0
24	1	121	3
24	1	121	6
24	1	121	8
24	1	121	13
24	1	121	14
24	1	121	15
24	1	121	19
24	1	121	20
24	1	121	21
24	1	121	22
24	1	122	3
24	1	122	6
24	1	122	14
24	1	122	19
24	1	122	21
24	1	123	3
24	1	123	14
24	1	124	0
25	1	125	1
25	1	125	5
25	1	125	8
25	1	125	13
25	1	125	14
25	1	125	17
25	1	125	18
25	1	125	19
25	1	125	20
25	1	125	23
25	1	126	5
25	1	126	17
25	1	126	19
25	1	126	20
25	1	126	23
25	1	127	17
25	1	127	20
25	1	128	0
26	1	129	1
26	1	129	3
26	1	129	4
26	1	129	8
26	1	129	10
26	1	129	12
26	1	129	14
26	1	129	16
26	1	129	17
26	1	129	24
26	1	130	1
26	1	130	8
26	1	130	14
26	1	130	16
26	1	131	1
26	1	131	14
26	1	131	16
26	1	132	0
27	1	133	2
27	1	133	6
27	1	133	7
27	1	133	10
27	1	133	12
27	1	133	14
27	1	133	16
27	1	133	17
27	1	133	24
27	1	133	25
27	1	134	2
27	1	134	6
27	1	134	24
27	1	135	6
27	1	135	24
27	1	136	0
28	1	137	1
28	1	137	3
28	1	137	4
28	1	137	5
28	1	137	7
28	1	137	14
28	1	137	15
28	1	137	22
28	1	137	23
28	1	137	24
28	1	138	1
28	1	138	14
28	1	138	23
28	1	139	0
29	1	140	4
29	1	140	5
29	1	140	7
29	1	140	8
29	1	140	11
29	1	140	14
29	1	140	16
29	1	140	17
29	1	140	21
29	1	140	23
29	1	141	4
29	1	141	5
29	1	141	11
29	1	141	14
29	1	141	21
29	1	141	23
29	1	142	11
29	1	142	14
29	1	142	21
29	1	143	14
29	1	144	0
30	1	145	4
30	1	145	5
30	1	145	6
30	1	145	7
30	1	145	8
30	1	145	12
30	1	145	16
30	1	145	19
30	1	145	21
30	1	145	23
30	1	146	4
30	1	146	6
30	1	146	7
30	1	146	19
30	1	146	21
30	1	147	7
30	1	148	7
30	1	149	0
31	1	150	2
31	1	150	4
31	1	150	10
31	1	150	12
31	1	150	13
31	1	150	15
31	1	150	16
31	1	150	17
31	1	150	18
31	1	150	20
31	1	151	2
31	1	151	15
31	1	151	17
31	1	152	2
31	1	153	0
32	1	154	4
32	1	154	7
32	1	154	8
32	1	154	12
32	1	154	17
32	1	154	19
32	1	154	20
32	1	154	21
32	1	154	22
32	1	154	25
32	1	155	7
32	1	155	12
32	1	155	17
32	1	155	25
32	1	156	7
32	1	156	17
32	1	156	25
32	1	157	17
32	1	158	0
33	1	159	7
33	1	159	9
33	1	159	12
33	1	159	13
33	1	159	16
33	1	159	18
33	1	159	19
33	1	159	21
33	1	159	22
33	1	159	23
33	1	160	7
33	1	160	13
33	1	160	18
33	1	160	22
33	1	160	23
33	1	161	7
33	1	162	7
33	1	163	0
34	1	164	4
34	1	164	7
34	1	164	9
34	1	164	12
34	1	164	13
34	1	164	16
34	1	164	17
34	1	164	19
34	1	164	20
34	1	164	25
34	1	165	7
34	1	165	16
34	1	165	20
34	1	166	7
34	1	166	16
34	1	167	7
34	1	168	0
35	1	169	2
35	1	169	3
35	1	169	13
35	1	169	14
35	1	169	17
35	1	169	18
35	1	169	19
35	1	169	22
35	1	169	23
35	1	169	25
35	1	170	2
35	1	170	14
35	1	170	17
35	1	170	19
35	1	171	2
35	1	171	14
35	1	171	19
35	1	172	14
35	1	172	19
35	1	173	14
35	1	174	14
35	1	175	0
36	1	176	1
36	1	176	3
36	1	176	5
36	1	176	6
36	1	176	7
36	1	176	8
36	1	176	9
36	1	176	14
36	1	176	19
36	1	176	20
36	1	177	1
36	1	177	3
36	1	177	5
36	1	177	9
36	1	177	14
36	1	178	1
36	1	178	5
36	1	179	1
36	1	180	0
37	1	181	2
37	1	181	3
37	1	181	9
37	1	181	10
37	1	181	11
37	1	181	12
37	1	181	13
37	1	181	18
37	1	181	24
37	1	181	25
37	1	182	10
37	1	182	12
37	1	182	18
37	1	182	24
37	1	183	10
37	1	183	12
37	1	183	18
37	1	184	12
37	1	185	0
38	1	186	1
38	1	186	3
38	1	186	7
38	1	186	8
38	1	186	9
38	1	186	10
38	1	186	14
38	1	186	15
38	1	186	20
38	1	186	21
38	1	187	7
38	1	187	8
38	1	187	9
38	1	187	10
38	1	187	14
38	1	187	20
38	1	188	7
38	1	188	9
38	1	188	14
38	1	189	14
38	1	190	0
39	1	191	1
39	1	191	3
39	1	191	4
39	1	191	6
39	1	191	7
39	1	191	11
39	1	191	14
39	1	191	16
39	1	191	24
39	1	191	25
39	1	192	7
39	1	192	25
39	1	193	7
39	1	194	0
40	1	195	1
40	1	195	5
40	1	195	10
40	1	195	13
40	1	195	15
40	1	195	16
40	1	195	20
40	1	195	21
40	1	195	24
40	1	195	25
40	1	196	1
40	1	196	13
40	1	196	21
40	1	197	1
40	1	198	0
41	1	199	7
41	1	199	8
41	1	199	10
41	1	199	13
41	1	199	14
41	1	199	16
41	1	199	17
41	1	199	18
41	1	199	24
41	1	199	25
41	1	200	7
41	1	200	10
41	1	200	17
41	1	200	18
41	1	200	25
41	1	201	7
41	1	201	17
41	1	201	18
41	1	201	25
41	1	202	7
41	1	202	25
41	1	203	0
42	1	204	1
42	1	204	6
42	1	204	9
42	1	204	10
42	1	204	12
42	1	204	13
42	1	204	18
42	1	204	19
42	1	204	20
42	1	204	21
42	1	205	1
42	1	205	6
42	1	205	13
42	1	205	19
42	1	205	20
42	1	206	1
42	1	206	6
42	1	206	19
42	1	207	0
43	1	208	2
43	1	208	5
43	1	208	8
43	1	208	13
43	1	208	17
43	1	208	18
43	1	208	20
43	1	208	21
43	1	208	22
43	1	208	25
43	1	209	2
43	1	209	8
43	1	209	13
43	1	209	17
43	1	209	20
43	1	210	2
43	1	210	8
43	1	210	17
43	1	210	20
43	1	211	20
43	1	212	0
44	1	213	2
44	1	213	6
44	1	213	7
44	1	213	12
44	1	213	13
44	1	213	14
44	1	213	15
44	1	213	17
44	1	213	20
44	1	213	22
44	1	214	6
44	1	214	7
44	1	214	12
44	1	214	17
44	1	215	6
44	1	216	0
45	1	217	1
45	1	217	8
45	1	217	13
45	1	217	14
45	1	217	15
45	1	217	18
45	1	217	20
45	1	217	22
45	1	217	23
45	1	217	24
45	1	218	1
45	1	218	18
45	1	218	23
45	1	218	24
45	1	219	1
45	1	220	1
45	1	221	0
46	1	222	2
46	1	222	10
46	1	222	11
46	1	222	13
46	1	222	14
46	1	222	16
46	1	222	17
46	1	222	19
46	1	222	20
46	1	222	25
46	1	223	17
46	1	223	19
46	1	223	25
46	1	224	17
46	1	224	25
46	1	225	17
46	1	226	0
47	1	227	2
47	1	227	3
47	1	227	4
47	1	227	6
47	1	227	11
47	1	227	13
47	1	227	16
47	1	227	23
47	1	227	24
47	1	227	25
47	1	228	3
47	1	228	6
47	1	228	23
47	1	229	3
47	1	230	0
48	1	231	3
48	1	231	4
48	1	231	8
48	1	231	9
48	1	231	11
48	1	231	13
48	1	231	14
48	1	231	20
48	1	231	22
48	1	231	23
48	1	232	3
48	1	232	8
48	1	232	20
48	1	232	22
48	1	233	20
48	1	233	22
48	1	234	20
48	1	235	20
48	1	236	20
48	1	237	0
49	1	238	2
49	1	238	5
49	1	238	7
49	1	238	8
49	1	238	9
49	1	238	10
49	1	238	16
49	1	238	18
49	1	238	22
49	1	238	25
49	1	239	2
49	1	239	8
49	1	239	18
49	1	240	8
49	1	241	0
50	1	242	1
50	1	242	3
50	1	242	4
50	1	242	7
50	1	242	10
50	1	242	11
50	1	242	12
50	1	242	20
50	1	242	24
50	1	242	25
50	1	243	10
50	1	243	11
50	1	243	24
50	1	244	0
51	1	245	3
51	1	245	4
51	1	245	5
51	1	245	8
51	1	245	13
51	1	245	17
51	1	245	20
51	1	245	21
51	1	245	22
51	1	245	23
51	1	246	3
51	1	246	20
51	1	246	22
51	1	246	23
51	1	247	20
51	1	248	0
52	1	249	1
52	1	249	2
52	1	249	3
52	1	249	6
52	1	249	11
52	1	249	13
52	1	249	16
52	1	249	19
52	1	249	20
52	1	249	24
52	1	250	6
52	1	250	11
52	1	250	20
52	1	250	24
52	1	251	11
52	1	251	20
52	1	251	24
52	1	252	20
52	1	253	20
52	1	254	0
53	1	255	5
53	1	255	7
53	1	255	8
53	1	255	11
53	1	255	12
53	1	255	13
53	1	255	18
53	1	255	19
53	1	255	20
53	1	255	25
53	1	256	5
53	1	256	11
53	1	256	19
53	1	256	25
53	1	257	5
53	1	257	11
53	1	257	25
53	1	258	11
53	1	259	11
53	1	260	0
54	1	261	3
54	1	261	8
54	1	261	9
54	1	261	10
54	1	261	12
54	1	261	14
54	1	261	18
54	1	261	22
54	1	261	23
54	1	261	24
54	1	262	10
54	1	262	18
54	1	262	22
54	1	263	22
54	1	264	0
55	1	265	2
55	1	265	3
55	1	265	4
55	1	265	6
55	1	265	9
55	1	265	10
55	1	265	14
55	1	265	21
55	1	265	23
55	1	265	25
55	1	266	2
55	1	266	10
55	1	266	23
55	1	266	25
55	1	267	10
55	1	267	25
55	1	268	0
56	1	269	3
56	1	269	5
56	1	269	7
56	1	269	8
56	1	269	9
56	1	269	11
56	1	269	12
56	1	269	20
56	1	269	21
56	1	269	25
56	1	270	11
56	1	270	12
56	1	270	20
56	1	270	21
56	1	271	0
57	1	272	3
57	1	272	6
57	1	272	7
57	1	272	10
57	1	272	14
57	1	272	16
57	1	272	18
57	1	272	19
57	1	272	21
57	1	272	22
57	1	273	3
57	1	273	14
57	1	273	22
57	1	274	3
57	1	274	22
57	1	275	0
58	1	276	1
58	1	276	6
58	1	276	8
58	1	276	9
58	1	276	14
58	1	276	15
58	1	276	16
58	1	276	21
58	1	276	23
58	1	276	24
58	1	277	1
58	1	277	6
58	1	277	8
58	1	277	15
58	1	278	8
58	1	279	8
58	1	280	8
58	1	281	0
59	1	282	1
59	1	282	5
59	1	282	6
59	1	282	9
59	1	282	10
59	1	282	14
59	1	282	17
59	1	282	18
59	1	282	23
59	1	282	24
59	1	283	5
59	1	283	14
59	1	283	17
59	1	283	18
59	1	284	14
59	1	284	18
59	1	285	18
59	1	286	18
59	1	287	0
60	1	288	5
60	1	288	7
60	1	288	8
60	1	288	11
60	1	288	16
60	1	288	17
60	1	288	20
60	1	288	21
60	1	288	22
60	1	288	23
60	1	289	5
60	1	289	7
60	1	289	11
60	1	289	16
60	1	289	20
60	1	289	21
60	1	289	23
60	1	290	16
60	1	291	16
60	1	292	0
61	1	293	4
61	1	293	5
61	1	293	7
61	1	293	8
61	1	293	10
61	1	293	11
61	1	293	16
61	1	293	17
61	1	293	20
61	1	293	21
61	1	294	10
61	1	294	17
61	1	294	21
61	1	295	0
62	1	296	1
62	1	296	4
62	1	296	5
62	1	296	9
62	1	296	10
62	1	296	13
62	1	296	20
62	1	296	21
62	1	296	23
62	1	296	24
62	1	297	5
62	1	297	13
62	1	297	20
62	1	298	5
62	1	298	20
62	1	299	0
63	1	300	1
63	1	300	2
63	1	300	5
63	1	300	6
63	1	300	10
63	1	300	13
63	1	300	14
63	1	300	16
63	1	300	18
63	1	300	24
63	1	301	1
63	1	301	5
63	1	301	6
63	1	301	10
63	1	301	16
63	1	301	24
63	1	302	1
63	1	302	24
63	1	303	1
63	1	304	0
64	1	305	1
64	1	305	6
64	1	305	7
64	1	305	9
64	1	305	14
64	1	305	15
64	1	305	16
64	1	305	17
64	1	305	19
64	1	305	23
64	1	306	6
64	1	306	7
64	1	306	9
64	1	306	17
64	1	306	23
64	1	307	7
64	1	308	7
64	1	309	7
64	1	310	7
64	1	311	0
65	1	312	3
65	1	312	4
65	1	312	5
65	1	312	7
65	1	312	14
65	1	312	15
65	1	312	20
65	1	312	21
65	1	312	23
65	1	312	24
65	1	313	4
65	1	313	5
65	1	313	20
65	1	313	21
65	1	313	24
65	1	314	4
65	1	314	24
65	1	315	4
65	1	316	0
66	1	317	3
66	1	317	6
66	1	317	7
66	1	317	10
66	1	317	12
66	1	317	13
66	1	317	15
66	1	317	17
66	1	317	20
66	1	317	23
66	1	318	7
66	1	318	10
66	1	318	17
66	1	318	20
66	1	319	7
66	1	320	7
66	1	321	7
66	1	322	0
67	1	323	5
67	1	323	8
67	1	323	11
67	1	323	12
67	1	323	13
67	1	323	15
67	1	323	16
67	1	323	18
67	1	323	22
67	1	323	24
67	1	324	5
67	1	324	11
67	1	324	13
67	1	324	15
67	1	324	18
67	1	324	22
67	1	325	11
67	1	325	13
67	1	325	18
67	1	326	0
68	1	327	5
68	1	327	6
68	1	327	7
68	1	327	9
68	1	327	10
68	1	327	11
68	1	327	20
68	1	327	22
68	1	327	24
68	1	327	25
68	1	328	6
68	1	328	7
68	1	328	9
68	1	328	10
68	1	328	20
68	1	329	6
68	1	329	7
68	1	329	10
68	1	330	7
68	1	330	10
68	1	331	10
68	1	332	0
69	1	333	3
69	1	333	4
69	1	333	7
69	1	333	8
69	1	333	10
69	1	333	17
69	1	333	19
69	1	333	20
69	1	333	22
69	1	333	24
69	1	334	3
69	1	334	4
69	1	334	10
69	1	334	19
69	1	334	20
69	1	334	24
69	1	335	10
69	1	335	24
69	1	336	24
69	1	337	24
69	1	338	24
69	1	339	0
70	1	340	1
70	1	340	7
70	1	340	12
70	1	340	13
70	1	340	15
70	1	340	16
70	1	340	17
70	1	340	18
70	1	340	23
70	1	340	24
70	1	341	15
70	1	341	17
70	1	341	23
70	1	342	17
70	1	343	17
70	1	344	17
70	1	345	17
70	1	346	0
71	1	347	1
71	1	347	2
71	1	347	4
71	1	347	6
71	1	347	13
71	1	347	16
71	1	347	17
71	1	347	21
71	1	347	22
71	1	347	23
71	1	348	4
71	1	348	6
71	1	348	13
71	1	348	16
71	1	348	23
71	1	349	4
71	1	349	6
71	1	349	13
71	1	349	23
71	1	350	0
72	1	351	4
72	1	351	6
72	1	351	8
72	1	351	9
72	1	351	13
72	1	351	15
72	1	351	20
72	1	351	21
72	1	351	22
72	1	351	25
72	1	352	8
72	1	352	21
72	1	352	25
72	1	353	25
72	1	354	25
72	1	355	0
73	1	356	1
73	1	356	3
73	1	356	6
73	1	356	7
73	1	356	8
73	1	356	12
73	1	356	17
73	1	356	18
73	1	356	21
73	1	356	23
73	1	357	3
73	1	357	7
73	1	357	12
73	1	357	18
73	1	358	3
73	1	358	7
73	1	359	3
73	1	360	0
74	1	361	2
74	1	361	3
74	1	361	5
74	1	361	6
74	1	361	8
74	1	361	11
74	1	361	18
74	1	361	21
74	1	361	22
74	1	361	25
74	1	362	8
74	1	362	11
74	1	362	21
74	1	362	25
74	1	363	25
74	1	364	25
74	1	365	0
75	1	366	1
75	1	366	2
75	1	366	4
75	1	366	7
75	1	366	10
75	1	366	12
75	1	366	14
75	1	366	16
75	1	366	19
75	1	366	24
75	1	367	10
75	1	367	14
75	1	367	16
75	1	367	19
75	1	368	10
75	1	368	16
75	1	369	10
75	1	369	16
75	1	370	0
76	1	371	4
76	1	371	11
76	1	371	12
76	1	371	17
76	1	371	18
76	1	371	19
76	1	371	20
76	1	371	21
76	1	371	23
76	1	371	24
76	1	372	11
76	1	372	18
76	1	372	20
76	1	372	21
76	1	373	18
76	1	374	0
77	1	375	3
77	1	375	4
77	1	375	6
77	1	375	8
77	1	375	9
77	1	375	15
77	1	375	21
77	1	375	22
77	1	375	23
77	1	375	24
77	1	376	4
77	1	376	6
77	1	376	9
77	1	376	23
77	1	377	6
77	1	377	23
77	1	378	0
78	1	379	1
78	1	379	2
78	1	379	6
78	1	379	8
78	1	379	9
78	1	379	15
78	1	379	19
78	1	379	20
78	1	379	23
78	1	379	24
78	1	380	1
78	1	380	15
78	1	380	19
78	1	380	20
78	1	380	24
78	1	381	20
78	1	381	24
78	1	382	20
78	1	383	20
78	1	384	0
79	1	385	3
79	1	385	7
79	1	385	9
79	1	385	10
79	1	385	11
79	1	385	14
79	1	385	16
79	1	385	17
79	1	385	19
79	1	385	21
79	1	386	10
79	1	386	14
79	1	386	16
79	1	386	17
79	1	387	16
79	1	387	17
79	1	388	0
80	1	389	1
80	1	389	7
80	1	389	8
80	1	389	11
80	1	389	14
80	1	389	15
80	1	389	16
80	1	389	20
80	1	389	21
80	1	389	22
80	1	390	1
80	1	390	8
80	1	390	16
80	1	391	0
81	1	392	5
81	1	392	6
81	1	392	7
81	1	392	8
81	1	392	9
81	1	392	13
81	1	392	16
81	1	392	19
81	1	392	22
81	1	392	24
81	1	393	5
81	1	393	9
81	1	393	13
81	1	393	16
81	1	393	19
81	1	393	24
81	1	394	9
81	1	394	19
81	1	395	19
81	1	396	19
81	1	397	19
81	1	398	19
81	1	399	0
82	1	400	2
82	1	400	3
82	1	400	4
82	1	400	6
82	1	400	7
82	1	400	8
82	1	400	11
82	1	400	13
82	1	400	18
82	1	400	25
82	1	401	4
82	1	401	11
82	1	401	13
82	1	401	18
82	1	402	13
82	1	402	18
82	1	403	18
82	1	404	0
83	1	405	1
83	1	405	2
83	1	405	3
83	1	405	9
83	1	405	10
83	1	405	15
83	1	405	17
83	1	405	20
83	1	405	21
83	1	405	23
83	1	406	3
83	1	406	15
83	1	406	20
83	1	407	3
83	1	408	0
84	1	409	3
84	1	409	5
84	1	409	9
84	1	409	11
84	1	409	12
84	1	409	13
84	1	409	15
84	1	409	18
84	1	409	19
84	1	409	22
84	1	410	3
84	1	410	12
84	1	410	22
84	1	411	3
84	1	412	0
85	1	413	1
85	1	413	4
85	1	413	7
85	1	413	11
85	1	413	15
85	1	413	18
85	1	413	19
85	1	413	22
85	1	413	23
85	1	413	24
85	1	414	1
85	1	414	4
85	1	414	7
85	1	414	22
85	1	414	23
85	1	414	24
85	1	415	4
85	1	415	24
85	1	416	4
85	1	417	4
85	1	418	4
85	1	419	0
86	1	420	1
86	1	420	2
86	1	420	13
86	1	420	14
86	1	420	15
86	1	420	16
86	1	420	17
86	1	420	20
86	1	420	21
86	1	420	23
86	1	421	1
86	1	421	2
86	1	421	17
86	1	421	21
86	1	422	21
86	1	423	21
86	1	424	21
86	1	425	21
86	1	426	21
86	1	427	0
87	1	428	2
87	1	428	5
87	1	428	6
87	1	428	7
87	1	428	8
87	1	428	9
87	1	428	10
87	1	428	12
87	1	428	16
87	1	428	25
87	1	429	9
87	1	429	10
87	1	430	10
87	1	431	10
87	1	432	0
88	1	433	4
88	1	433	6
88	1	433	10
88	1	433	11
88	1	433	12
88	1	433	13
88	1	433	16
88	1	433	17
88	1	433	18
88	1	433	20
88	1	434	10
88	1	434	20
88	1	435	20
88	1	436	0
89	1	437	3
89	1	437	7
89	1	437	9
89	1	437	13
89	1	437	14
89	1	437	15
89	1	437	18
89	1	437	22
89	1	437	24
89	1	437	25
89	1	438	3
89	1	438	14
89	1	439	0
90	1	440	2
90	1	440	4
90	1	440	6
90	1	440	7
90	1	440	10
90	1	440	11
90	1	440	17
90	1	440	18
90	1	440	20
90	1	440	23
90	1	441	6
90	1	441	17
90	1	441	18
90	1	442	0
91	1	443	4
91	1	443	6
91	1	443	8
91	1	443	9
91	1	443	13
91	1	443	14
91	1	443	15
91	1	443	20
91	1	443	24
91	1	443	25
91	1	444	4
91	1	444	8
91	1	444	9
91	1	444	13
91	1	445	8
91	1	446	0
92	1	447	3
92	1	447	4
92	1	447	6
92	1	447	7
92	1	447	9
92	1	447	11
92	1	447	13
92	1	447	14
92	1	447	15
92	1	447	23
92	1	448	4
92	1	448	7
92	1	449	7
92	1	450	0
93	1	451	2
93	1	451	4
93	1	451	7
93	1	451	10
93	1	451	11
93	1	451	12
93	1	451	13
93	1	451	16
93	1	451	20
93	1	451	21
93	1	452	2
93	1	452	4
93	1	452	13
93	1	452	16
93	1	452	21
93	1	453	13
93	1	453	16
93	1	454	16
93	1	455	16
93	1	456	16
93	1	457	0
94	1	458	1
94	1	458	10
94	1	458	12
94	1	458	14
94	1	458	17
94	1	458	19
94	1	458	21
94	1	458	23
94	1	458	24
94	1	458	25
94	1	459	24
94	1	459	25
94	1	460	24
94	1	460	25
94	1	461	25
94	1	462	25
94	1	463	0
95	1	464	3
95	1	464	4
95	1	464	6
95	1	464	7
95	1	464	9
95	1	464	12
95	1	464	13
95	1	464	14
95	1	464	15
95	1	464	18
95	1	465	12
95	1	465	14
95	1	465	15
95	1	466	15
95	1	467	0
96	1	468	1
96	1	468	4
96	1	468	7
96	1	468	8
96	1	468	11
96	1	468	14
96	1	468	16
96	1	468	19
96	1	468	20
96	1	468	23
96	1	469	4
96	1	469	16
96	1	469	20
96	1	470	16
96	1	471	0
97	1	472	3
97	1	472	9
97	1	472	10
97	1	472	16
97	1	472	19
97	1	472	21
97	1	472	22
97	1	472	23
97	1	472	24
97	1	472	25
97	1	473	3
97	1	473	10
97	1	473	16
97	1	473	21
97	1	473	24
97	1	474	0
98	1	475	1
98	1	475	7
98	1	475	8
98	1	475	12
98	1	475	15
98	1	475	16
98	1	475	18
98	1	475	19
98	1	475	22
98	1	475	24
98	1	476	8
98	1	476	12
98	1	476	18
98	1	476	22
98	1	477	22
98	1	478	0
99	1	479	1
99	1	479	4
99	1	479	6
99	1	479	7
99	1	479	9
99	1	479	10
99	1	479	12
99	1	479	17
99	1	479	20
99	1	479	21
99	1	480	1
99	1	480	10
99	1	480	20
99	1	480	21
99	1	481	0
100	1	482	1
100	1	482	3
100	1	482	4
100	1	482	5
100	1	482	11
100	1	482	13
100	1	482	14
100	1	482	18
100	1	482	20
100	1	482	24
100	1	483	3
100	1	483	13
100	1	483	20
100	1	484	3
100	1	485	0
101	1	486	6
101	1	486	8
101	1	486	10
101	1	486	12
101	1	486	14
101	1	486	16
101	1	486	17
101	1	486	23
101	1	486	24
101	1	486	25
101	1	487	12
101	1	487	16
101	1	487	23
101	1	487	25
101	1	488	16
101	1	488	23
101	1	489	16
101	1	490	0
102	1	491	4
102	1	491	5
102	1	491	6
102	1	491	8
102	1	491	10
102	1	491	14
102	1	491	15
102	1	491	17
102	1	491	18
102	1	491	19
102	1	492	5
102	1	492	10
102	1	492	17
102	1	493	0
103	1	494	1
103	1	494	6
103	1	494	9
103	1	494	10
103	1	494	11
103	1	494	14
103	1	494	17
103	1	494	23
103	1	494	24
103	1	494	25
103	1	495	10
103	1	495	14
103	1	495	23
103	1	496	10
103	1	496	23
103	1	497	10
103	1	498	10
103	1	499	0
104	1	500	1
104	1	500	4
104	1	500	7
104	1	500	11
104	1	500	12
104	1	500	15
104	1	500	17
104	1	500	19
104	1	500	22
104	1	500	24
104	1	501	7
104	1	501	11
104	1	501	22
104	1	502	7
104	1	502	22
104	1	503	22
104	1	504	22
104	1	505	0
105	1	506	1
105	1	506	2
105	1	506	3
105	1	506	7
105	1	506	8
105	1	506	10
105	1	506	14
105	1	506	18
105	1	506	23
105	1	506	25
105	1	507	7
105	1	507	14
105	1	507	18
105	1	508	0
106	1	509	2
106	1	509	4
106	1	509	7
106	1	509	8
106	1	509	10
106	1	509	13
106	1	509	14
106	1	509	18
106	1	509	21
106	1	509	23
106	1	510	8
106	1	510	14
106	1	510	18
106	1	511	8
106	1	512	0
107	1	513	4
107	1	513	5
107	1	513	7
107	1	513	8
107	1	513	12
107	1	513	14
107	1	513	16
107	1	513	19
107	1	513	21
107	1	513	24
107	1	514	4
107	1	514	14
107	1	514	16
107	1	514	19
107	1	515	4
107	1	515	16
107	1	515	19
107	1	516	16
107	1	516	19
107	1	517	16
107	1	517	19
107	1	518	0
108	1	519	1
108	1	519	4
108	1	519	5
108	1	519	6
108	1	519	8
108	1	519	10
108	1	519	14
108	1	519	18
108	1	519	20
108	1	519	22
108	1	520	1
108	1	520	8
108	1	521	8
108	1	522	8
108	1	523	0
109	1	524	1
109	1	524	4
109	1	524	8
109	1	524	9
109	1	524	13
109	1	524	15
109	1	524	16
109	1	524	18
109	1	524	19
109	1	524	25
109	1	525	1
109	1	525	8
109	1	525	19
109	1	526	0
110	1	527	3
110	1	527	4
110	1	527	7
110	1	527	8
110	1	527	10
110	1	527	13
110	1	527	18
110	1	527	20
110	1	527	21
110	1	527	25
110	1	528	13
110	1	528	18
110	1	528	20
110	1	529	13
110	1	530	13
110	1	531	0
111	1	532	3
111	1	532	8
111	1	532	10
111	1	532	14
111	1	532	17
111	1	532	18
111	1	532	20
111	1	532	21
111	1	532	23
111	1	532	25
111	1	533	21
111	1	533	23
111	1	534	23
111	1	535	0
112	1	536	1
112	1	536	2
112	1	536	6
112	1	536	8
112	1	536	10
112	1	536	12
112	1	536	13
112	1	536	14
112	1	536	18
112	1	536	21
112	1	537	8
112	1	537	12
112	1	537	13
112	1	537	21
112	1	538	8
112	1	539	0
113	1	540	1
113	1	540	3
113	1	540	4
113	1	540	5
113	1	540	10
113	1	540	14
113	1	540	17
113	1	540	21
113	1	540	23
113	1	540	25
113	1	541	1
113	1	541	21
113	1	541	23
113	1	542	21
113	1	542	23
113	1	543	21
113	1	543	23
113	1	544	0
114	1	545	2
114	1	545	4
114	1	545	8
114	1	545	9
114	1	545	10
114	1	545	16
114	1	545	19
114	1	545	20
114	1	545	21
114	1	545	22
114	1	546	16
114	1	546	20
114	1	546	22
114	1	547	22
114	1	548	22
114	1	549	0
115	1	550	2
115	1	550	3
115	1	550	4
115	1	550	8
115	1	550	12
115	1	550	15
115	1	550	19
115	1	550	23
115	1	550	24
115	1	550	25
115	1	551	2
115	1	551	4
115	1	551	15
115	1	551	23
115	1	551	25
115	1	552	2
115	1	552	15
115	1	553	2
115	1	554	0
116	1	555	3
116	1	555	4
116	1	555	5
116	1	555	11
116	1	555	13
116	1	555	15
116	1	555	19
116	1	555	21
116	1	555	22
116	1	555	25
116	1	556	3
116	1	556	5
116	1	556	15
116	1	556	19
116	1	556	21
116	1	557	3
116	1	558	0
117	1	559	3
117	1	559	4
117	1	559	6
117	1	559	8
117	1	559	12
117	1	559	15
117	1	559	17
117	1	559	18
117	1	559	24
117	1	559	25
117	1	560	3
117	1	560	6
117	1	560	8
117	1	560	15
117	1	561	8
117	1	562	0
118	1	563	2
118	1	563	8
118	1	563	10
118	1	563	13
118	1	563	14
118	1	563	15
118	1	563	17
118	1	563	18
118	1	563	21
118	1	563	25
118	1	564	8
118	1	564	10
118	1	564	13
118	1	564	18
118	1	564	25
118	1	565	8
118	1	565	13
118	1	565	25
118	1	566	8
118	1	566	13
118	1	566	25
118	1	567	0
119	1	568	3
119	1	568	10
119	1	568	11
119	1	568	12
119	1	568	14
119	1	568	19
119	1	568	22
119	1	568	23
119	1	568	24
119	1	568	25
119	1	569	3
119	1	569	10
119	1	569	11
119	1	569	14
119	1	569	23
119	1	570	11
119	1	571	0
120	1	572	1
120	1	572	3
120	1	572	4
120	1	572	7
120	1	572	11
120	1	572	12
120	1	572	18
120	1	572	20
120	1	572	23
120	1	572	25
120	1	573	4
120	1	574	4
120	1	575	4
120	1	576	4
120	1	577	0
121	1	578	2
121	1	578	3
121	1	578	5
121	1	578	9
121	1	578	11
121	1	578	17
121	1	578	18
121	1	578	20
121	1	578	24
121	1	578	25
121	1	579	2
121	1	579	9
121	1	579	11
121	1	579	18
121	1	579	25
121	1	580	2
121	1	580	11
121	1	580	18
121	1	581	0
122	1	582	1
122	1	582	2
122	1	582	4
122	1	582	5
122	1	582	6
122	1	582	14
122	1	582	16
122	1	582	20
122	1	582	22
122	1	582	24
122	1	583	2
122	1	583	5
122	1	583	6
122	1	583	20
122	1	583	22
122	1	584	0
123	1	585	2
123	1	585	3
123	1	585	4
123	1	585	6
123	1	585	11
123	1	585	12
123	1	585	19
123	1	585	21
123	1	585	22
123	1	585	25
123	1	586	21
123	1	587	0
124	1	588	2
124	1	588	3
124	1	588	6
124	1	588	8
124	1	588	9
124	1	588	10
124	1	588	15
124	1	588	16
124	1	588	21
124	1	588	22
124	1	589	15
124	1	589	16
124	1	590	0
125	1	591	3
125	1	591	5
125	1	591	6
125	1	591	9
125	1	591	12
125	1	591	13
125	1	591	18
125	1	591	22
125	1	591	24
125	1	591	25
125	1	592	12
125	1	592	13
125	1	592	24
125	1	592	25
125	1	593	12
125	1	594	12
125	1	595	0
126	1	596	1
126	1	596	4
126	1	596	5
126	1	596	6
126	1	596	13
126	1	596	14
126	1	596	15
126	1	596	16
126	1	596	21
126	1	596	24
126	1	597	4
126	1	597	6
126	1	597	13
126	1	597	15
126	1	597	21
126	1	598	6
126	1	598	13
126	1	599	0
127	1	600	2
127	1	600	4
127	1	600	7
127	1	600	12
127	1	600	13
127	1	600	14
127	1	600	15
127	1	600	20
127	1	600	21
127	1	600	24
127	1	601	2
127	1	601	4
127	1	601	15
127	1	601	21
127	1	601	24
127	1	602	4
127	1	602	15
127	1	602	21
127	1	602	24
127	1	603	24
127	1	604	0
128	1	605	1
128	1	605	6
128	1	605	8
128	1	605	9
128	1	605	12
128	1	605	15
128	1	605	19
128	1	605	20
128	1	605	22
128	1	605	24
128	1	606	1
128	1	606	9
128	1	606	19
128	1	606	20
128	1	607	1
128	1	608	0
129	1	609	3
129	1	609	5
129	1	609	6
129	1	609	8
129	1	609	13
129	1	609	17
129	1	609	18
129	1	609	21
129	1	609	22
129	1	609	24
129	1	610	3
129	1	610	5
129	1	610	17
129	1	610	18
129	1	610	24
129	1	611	17
129	1	611	24
129	1	612	24
129	1	613	24
129	1	614	24
129	1	615	0
130	1	616	3
130	1	616	4
130	1	616	5
130	1	616	7
130	1	616	8
130	1	616	11
130	1	616	13
130	1	616	14
130	1	616	20
130	1	616	23
130	1	617	8
130	1	617	11
130	1	617	13
130	1	617	20
130	1	617	23
130	1	618	8
130	1	618	11
130	1	618	23
130	1	619	11
130	1	620	0
131	1	621	4
131	1	621	7
131	1	621	11
131	1	621	13
131	1	621	14
131	1	621	17
131	1	621	18
131	1	621	19
131	1	621	21
131	1	621	23
131	1	622	14
131	1	622	19
131	1	622	23
131	1	623	14
131	1	623	19
131	1	624	14
131	1	624	19
131	1	625	19
131	1	626	0
132	1	627	5
132	1	627	7
132	1	627	8
132	1	627	9
132	1	627	11
132	1	627	13
132	1	627	16
132	1	627	18
132	1	627	19
132	1	627	20
132	1	628	5
132	1	628	16
132	1	628	20
132	1	629	16
132	1	629	20
132	1	630	16
132	1	631	0
133	1	632	2
133	1	632	3
133	1	632	5
133	1	632	7
133	1	632	9
133	1	632	12
133	1	632	15
133	1	632	18
133	1	632	19
133	1	632	23
133	1	633	5
133	1	633	15
133	1	633	19
133	1	634	0
134	1	635	2
134	1	635	3
134	1	635	10
134	1	635	14
134	1	635	15
134	1	635	16
134	1	635	17
134	1	635	21
134	1	635	23
134	1	635	25
134	1	636	15
134	1	636	17
134	1	637	15
134	1	638	15
134	1	639	15
134	1	640	15
134	1	641	15
134	1	642	15
134	1	643	15
134	1	644	0
135	1	645	1
135	1	645	2
135	1	645	3
135	1	645	6
135	1	645	7
135	1	645	12
135	1	645	14
135	1	645	15
135	1	645	17
135	1	645	24
135	1	646	2
135	1	646	7
135	1	646	12
135	1	646	24
135	1	647	2
135	1	647	12
135	1	647	24
135	1	648	12
135	1	648	24
135	1	649	12
135	1	650	12
135	1	651	12
135	1	652	12
135	1	653	0
136	1	654	4
136	1	654	5
136	1	654	6
136	1	654	8
136	1	654	9
136	1	654	10
136	1	654	11
136	1	654	15
136	1	654	21
136	1	654	24
136	1	655	4
136	1	655	6
136	1	655	9
136	1	656	4
136	1	656	6
136	1	657	0
137	1	658	2
137	1	658	3
137	1	658	8
137	1	658	12
137	1	658	13
137	1	658	16
137	1	658	18
137	1	658	19
137	1	658	20
137	1	658	22
137	1	659	2
137	1	659	13
137	1	659	16
137	1	659	18
137	1	659	22
137	1	660	2
137	1	660	13
137	1	660	18
137	1	660	22
137	1	661	2
137	1	661	13
137	1	662	0
138	1	663	1
138	1	663	3
138	1	663	8
138	1	663	10
138	1	663	12
138	1	663	14
138	1	663	15
138	1	663	18
138	1	663	20
138	1	663	25
138	1	664	8
138	1	664	12
138	1	664	25
138	1	665	8
138	1	666	8
138	1	667	0
139	1	668	3
139	1	668	4
139	1	668	5
139	1	668	6
139	1	668	8
139	1	668	14
139	1	668	18
139	1	668	19
139	1	668	21
139	1	668	22
139	1	669	3
139	1	669	8
139	1	669	14
139	1	669	21
139	1	670	3
139	1	671	3
139	1	672	3
139	1	673	3
139	1	674	0
140	1	675	1
140	1	675	6
140	1	675	8
140	1	675	9
140	1	675	12
140	1	675	18
140	1	675	19
140	1	675	20
140	1	675	21
140	1	675	25
140	1	676	1
140	1	676	9
140	1	676	18
140	1	677	9
140	1	677	18
140	1	678	0
141	1	679	1
141	1	679	3
141	1	679	4
141	1	679	5
141	1	679	6
141	1	679	9
141	1	679	16
141	1	679	23
141	1	679	24
141	1	679	25
141	1	680	1
141	1	680	5
141	1	680	23
141	1	680	24
141	1	680	25
141	1	681	1
141	1	681	5
141	1	681	24
141	1	681	25
141	1	682	0
142	1	683	3
142	1	683	14
142	1	683	16
142	1	683	17
142	1	683	18
142	1	683	19
142	1	683	20
142	1	683	21
142	1	683	22
142	1	683	25
142	1	684	3
142	1	684	17
142	1	684	18
142	1	684	19
142	1	685	18
142	1	686	18
142	1	687	0
143	1	688	5
143	1	688	6
143	1	688	8
143	1	688	10
143	1	688	13
143	1	688	15
143	1	688	17
143	1	688	18
143	1	688	20
143	1	688	25
143	1	689	10
143	1	689	18
143	1	689	20
143	1	689	25
143	1	690	0
144	1	691	4
144	1	691	5
144	1	691	10
144	1	691	12
144	1	691	14
144	1	691	15
144	1	691	16
144	1	691	21
144	1	691	24
144	1	691	25
144	1	692	5
144	1	692	14
144	1	692	15
144	1	692	16
144	1	692	25
144	1	693	5
144	1	693	15
144	1	693	25
144	1	694	5
144	1	694	25
144	1	695	0
145	1	696	2
145	1	696	3
145	1	696	6
145	1	696	8
145	1	696	12
145	1	696	17
145	1	696	18
145	1	696	19
145	1	696	23
145	1	696	25
145	1	697	6
145	1	697	12
145	1	697	17
145	1	698	17
145	1	699	17
145	1	700	17
145	1	701	0
146	1	702	11
146	1	702	12
146	1	702	15
146	1	702	16
146	1	702	17
146	1	702	18
146	1	702	19
146	1	702	21
146	1	702	22
146	1	702	24
146	1	703	12
146	1	703	16
146	1	703	19
146	1	704	12
146	1	704	19
146	1	705	19
146	1	706	0
147	1	707	1
147	1	707	2
147	1	707	5
147	1	707	9
147	1	707	10
147	1	707	13
147	1	707	18
147	1	707	19
147	1	707	22
147	1	707	23
147	1	708	10
147	1	708	13
147	1	708	18
147	1	708	23
147	1	709	10
147	1	709	13
147	1	710	10
147	1	710	13
147	1	711	0
148	1	712	2
148	1	712	3
148	1	712	5
148	1	712	6
148	1	712	7
148	1	712	10
148	1	712	11
148	1	712	13
148	1	712	19
148	1	712	24
148	1	713	7
148	1	713	10
148	1	714	0
149	1	715	2
149	1	715	4
149	1	715	6
149	1	715	7
149	1	715	9
149	1	715	12
149	1	715	16
149	1	715	17
149	1	715	19
149	1	715	21
149	1	716	2
149	1	716	4
149	1	716	6
149	1	716	9
149	1	716	17
149	1	716	19
149	1	717	4
149	1	717	6
149	1	717	17
149	1	717	19
149	1	718	6
149	1	719	6
149	1	720	6
149	1	721	6
149	1	722	0
150	1	723	1
150	1	723	6
150	1	723	13
150	1	723	16
150	1	723	17
150	1	723	19
150	1	723	21
150	1	723	22
150	1	723	23
150	1	723	25
150	1	724	13
150	1	724	16
150	1	724	17
150	1	724	21
150	1	724	22
150	1	725	22
150	1	726	22
150	1	727	0
151	1	728	1
151	1	728	2
151	1	728	5
151	1	728	9
151	1	728	12
151	1	728	14
151	1	728	15
151	1	728	17
151	1	728	18
151	1	728	24
151	1	729	5
151	1	729	18
151	1	729	24
594	1	2796	17
594	1	2796	18
594	1	2796	23
594	1	2797	2
594	1	2797	8
594	1	2797	17
594	1	2798	17
594	1	2799	17
594	1	2800	0
595	1	2801	4
595	1	2801	5
595	1	2801	6
595	1	2801	8
595	1	2801	10
595	1	2801	11
595	1	2801	13
595	1	2801	14
595	1	2801	21
595	1	2801	23
595	1	2802	5
595	1	2802	10
595	1	2802	11
595	1	2802	14
595	1	2802	21
595	1	2803	10
595	1	2803	11
595	1	2804	0
596	1	2805	1
596	1	2805	2
596	1	2805	3
596	1	2805	4
596	1	2805	9
596	1	2805	15
596	1	2805	16
596	1	2805	17
596	1	2805	21
596	1	2805	24
596	1	2806	9
596	1	2806	15
596	1	2806	21
596	1	2806	24
596	1	2807	21
596	1	2808	0
597	1	2809	3
597	1	2809	6
597	1	2809	9
597	1	2809	10
597	1	2809	11
597	1	2809	12
597	1	2809	14
597	1	2809	16
597	1	2809	17
597	1	2809	23
597	1	2810	3
597	1	2810	6
597	1	2810	9
597	1	2810	16
597	1	2810	17
597	1	2811	17
597	1	2812	17
597	1	2813	17
597	1	2814	17
597	1	2815	17
597	1	2816	17
597	1	2817	0
598	1	2818	6
598	1	2818	8
598	1	2818	16
598	1	2818	18
598	1	2818	19
598	1	2818	20
598	1	2818	21
598	1	2818	22
598	1	2818	23
598	1	2818	25
598	1	2819	16
598	1	2819	19
598	1	2819	25
598	1	2820	16
598	1	2821	16
598	1	2822	16
598	1	2823	0
599	1	2824	3
599	1	2824	4
599	1	2824	6
599	1	2824	8
599	1	2824	10
599	1	2824	11
599	1	2824	17
599	1	2824	18
599	1	2824	19
599	1	2824	23
599	1	2825	10
599	1	2825	11
599	1	2825	19
599	1	2825	23
599	1	2826	10
599	1	2827	0
600	1	2828	2
600	1	2828	3
600	1	2828	4
612	1	2881	2
612	1	2881	5
612	1	2881	8
612	1	2881	9
612	1	2881	14
612	1	2881	15
612	1	2881	17
612	1	2881	21
612	1	2881	22
612	1	2881	24
612	1	2882	5
612	1	2882	8
612	1	2882	15
612	1	2883	0
613	1	2884	4
613	1	2884	5
613	1	2884	8
613	1	2884	9
613	1	2884	13
613	1	2884	15
613	1	2884	17
613	1	2884	19
613	1	2884	24
613	1	2884	25
613	1	2885	4
613	1	2885	5
613	1	2885	9
613	1	2885	13
613	1	2885	15
613	1	2885	25
613	1	2886	0
614	1	2887	4
614	1	2887	5
614	1	2887	6
614	1	2887	8
614	1	2887	13
614	1	2887	14
614	1	2887	15
614	1	2887	16
614	1	2887	23
614	1	2887	25
614	1	2888	5
614	1	2888	6
614	1	2888	14
614	1	2888	16
614	1	2888	23
614	1	2889	5
614	1	2890	5
614	1	2891	0
615	1	2892	1
615	1	2892	2
615	1	2892	3
615	1	2892	7
615	1	2892	11
615	1	2892	12
615	1	2892	13
615	1	2892	15
615	1	2892	24
615	1	2892	25
615	1	2893	2
615	1	2893	3
615	1	2893	7
615	1	2893	12
615	1	2893	13
615	1	2893	15
615	1	2894	12
615	1	2895	12
615	1	2896	12
615	1	2897	0
616	1	2898	2
616	1	2898	3
616	1	2898	4
616	1	2898	5
616	1	2898	7
616	1	2898	8
616	1	2898	11
616	1	2898	13
616	1	2898	19
616	1	2898	25
616	1	2899	4
616	1	2899	11
616	1	2900	0
617	1	2901	2
617	1	2901	3
617	1	2901	6
617	1	2901	7
617	1	2901	8
617	1	2901	11
617	1	2901	12
617	1	2901	18
617	1	2901	19
617	1	2901	24
617	1	2902	12
617	1	2902	18
617	1	2903	0
618	1	2904	3
618	1	2904	6
618	1	2904	7
618	1	2904	12
618	1	2904	13
618	1	2904	15
618	1	2904	16
618	1	2904	19
618	1	2904	23
618	1	2904	25
618	1	2905	7
618	1	2905	12
618	1	2905	15
618	1	2905	19
618	1	2905	25
618	1	2906	12
618	1	2906	25
618	1	2907	12
618	1	2907	25
618	1	2908	25
618	1	2909	25
618	1	2910	25
618	1	2911	0
619	1	2912	3
619	1	2912	5
619	1	2912	7
619	1	2912	8
619	1	2912	9
619	1	2912	12
619	1	2912	13
619	1	2912	18
619	1	2912	21
619	1	2912	24
619	1	2913	5
619	1	2913	13
619	1	2913	18
619	1	2914	13
619	1	2915	0
620	1	2916	2
620	1	2916	4
620	1	2916	6
620	1	2916	7
620	1	2916	8
620	1	2916	9
620	1	2916	10
620	1	2916	13
620	1	2916	16
620	1	2916	23
620	1	2917	2
620	1	2917	7
620	1	2917	8
620	1	2917	13
620	1	2918	13
620	1	2919	0
621	1	2920	3
621	1	2920	8
621	1	2920	11
621	1	2920	15
621	1	2920	16
621	1	2920	19
621	1	2920	20
621	1	2920	23
621	1	2920	24
621	1	2920	25
621	1	2921	8
621	1	2921	11
621	1	2921	20
621	1	2921	23
621	1	2921	25
621	1	2922	20
621	1	2922	23
621	1	2922	25
621	1	2923	0
622	1	2924	1
622	1	2924	10
622	1	2924	11
622	1	2924	15
622	1	2924	16
622	1	2924	17
622	1	2924	19
622	1	2924	21
622	1	2924	22
622	1	2924	25
622	1	2925	1
622	1	2925	15
622	1	2925	16
622	1	2925	17
622	1	2925	19
622	1	2926	16
622	1	2927	0
623	1	2928	2
623	1	2928	5
623	1	2928	8
623	1	2928	10
623	1	2928	11
623	1	2928	12
623	1	2928	20
623	1	2928	22
623	1	2928	23
623	1	2928	25
623	1	2929	5
623	1	2929	8
623	1	2929	10
623	1	2929	22
623	1	2929	23
623	1	2930	5
623	1	2930	8
623	1	2931	8
623	1	2932	0
624	1	2933	5
624	1	2933	9
624	1	2933	11
624	1	2933	12
624	1	2933	13
624	1	2933	16
624	1	2933	19
624	1	2933	21
624	1	2933	23
624	1	2933	24
624	1	2934	5
624	1	2934	9
624	1	2934	21
624	1	2935	5
624	1	2936	5
624	1	2937	0
625	1	2938	7
625	1	2938	12
625	1	2938	13
625	1	2938	14
625	1	2938	16
625	1	2938	18
625	1	2938	19
625	1	2938	22
625	1	2938	23
625	1	2938	25
625	1	2939	14
625	1	2939	16
625	1	2939	19
625	1	2939	25
625	1	2940	16
625	1	2940	19
625	1	2941	16
625	1	2941	19
625	1	2942	0
626	1	2943	2
626	1	2943	3
626	1	2943	6
626	1	2943	7
626	1	2943	13
626	1	2943	14
626	1	2943	21
626	1	2943	22
626	1	2943	23
626	1	2943	24
626	1	2944	3
626	1	2944	14
626	1	2944	22
626	1	2944	23
626	1	2945	3
626	1	2945	23
626	1	2946	0
627	1	2947	1
627	1	2947	5
627	1	2947	10
627	1	2947	14
627	1	2947	16
627	1	2947	17
627	1	2947	18
627	1	2947	19
627	1	2947	21
627	1	2947	23
627	1	2948	14
627	1	2948	17
627	1	2948	19
627	1	2949	19
627	1	2950	0
628	1	2951	2
628	1	2951	4
628	1	2951	5
628	1	2951	7
628	1	2951	11
628	1	2951	12
628	1	2951	14
628	1	2951	23
628	1	2951	24
628	1	2951	25
628	1	2952	7
628	1	2952	14
628	1	2952	23
628	1	2952	24
628	1	2952	25
628	1	2953	14
628	1	2953	24
628	1	2953	25
628	1	2954	0
629	1	2955	5
629	1	2955	7
629	1	2955	9
629	1	2955	10
629	1	2955	14
629	1	2955	15
629	1	2955	20
629	1	2955	21
629	1	2955	22
629	1	2955	25
629	1	2956	10
629	1	2956	15
629	1	2957	0
630	1	2958	1
630	1	2958	2
630	1	2958	3
630	1	2958	5
630	1	2958	9
630	1	2958	15
630	1	2958	16
630	1	2958	17
630	1	2958	19
630	1	2958	21
630	1	2959	2
630	1	2959	9
630	1	2959	17
630	1	2959	19
630	1	2960	17
630	1	2961	0
631	1	2962	2
631	1	2962	4
631	1	2962	5
631	1	2962	8
631	1	2962	10
631	1	2962	13
631	1	2962	16
631	1	2962	19
631	1	2962	21
631	1	2962	23
631	1	2963	5
631	1	2963	8
631	1	2963	16
631	1	2963	19
631	1	2963	23
631	1	2964	8
631	1	2964	16
631	1	2964	19
631	1	2965	0
632	1	2966	2
632	1	2966	5
632	1	2966	9
632	1	2966	10
632	1	2966	14
632	1	2966	15
632	1	2966	16
632	1	2966	21
632	1	2966	24
632	1	2966	25
632	1	2967	5
632	1	2967	10
632	1	2967	15
632	1	2967	16
632	1	2967	21
632	1	2967	24
632	1	2968	16
632	1	2968	24
632	1	2969	16
632	1	2970	16
632	1	2971	0
633	1	2972	1
633	1	2972	2
633	1	2972	7
633	1	2972	9
633	1	2972	10
633	1	2972	15
633	1	2972	16
633	1	2972	17
633	1	2972	22
633	1	2972	23
633	1	2973	7
633	1	2973	15
633	1	2973	22
633	1	2973	23
633	1	2974	7
633	1	2974	22
633	1	2974	23
633	1	2975	7
633	1	2976	7
633	1	2977	0
634	1	2978	1
634	1	2978	2
634	1	2978	3
634	1	2978	4
634	1	2978	8
634	1	2978	9
634	1	2978	11
634	1	2978	18
634	1	2978	19
634	1	2978	22
634	1	2979	1
634	1	2979	3
634	1	2979	18
634	1	2980	3
634	1	2980	18
634	1	2981	3
634	1	2981	18
634	1	2982	3
634	1	2983	0
635	1	2984	1
635	1	2984	4
635	1	2984	10
635	1	2984	11
635	1	2984	12
635	1	2984	16
635	1	2984	17
635	1	2984	19
635	1	2984	21
635	1	2984	22
635	1	2985	1
635	1	2985	10
635	1	2985	16
635	1	2985	17
635	1	2986	17
635	1	2987	0
636	1	2988	2
636	1	2988	4
636	1	2988	5
636	1	2988	8
636	1	2988	15
636	1	2988	16
636	1	2988	18
636	1	2988	21
636	1	2988	24
636	1	2988	25
636	1	2989	5
636	1	2989	8
636	1	2989	21
636	1	2990	8
636	1	2991	8
636	1	2992	0
637	1	2993	6
637	1	2993	9
637	1	2993	10
637	1	2993	11
637	1	2993	14
637	1	2993	17
637	1	2993	20
637	1	2993	21
637	1	2993	22
637	1	2993	23
637	1	2994	6
637	1	2994	10
637	1	2994	14
637	1	2994	22
637	1	2994	23
637	1	2995	10
637	1	2995	14
637	1	2996	0
638	1	2997	1
638	1	2997	6
638	1	2997	10
638	1	2997	12
638	1	2997	13
638	1	2997	15
638	1	2997	16
638	1	2997	18
638	1	2997	21
638	1	2997	24
638	1	2998	1
638	1	2998	15
638	1	2998	24
638	1	2999	15
638	1	3000	0
639	1	3001	1
639	1	3001	3
639	1	3001	5
639	1	3001	7
639	1	3001	8
639	1	3001	9
639	1	3001	15
639	1	3001	16
639	1	3001	17
639	1	3001	22
639	1	3002	1
639	1	3002	5
639	1	3002	9
639	1	3002	16
639	1	3002	17
639	1	3003	17
639	1	3004	17
639	1	3005	17
639	1	3006	17
639	1	3007	17
639	1	3008	17
639	1	3009	17
639	1	3010	0
640	1	3011	6
640	1	3011	12
640	1	3011	14
640	1	3011	16
640	1	3011	17
640	1	3011	18
640	1	3011	19
640	1	3011	20
640	1	3011	22
640	1	3011	25
640	1	3012	12
640	1	3012	18
640	1	3012	19
640	1	3012	22
640	1	3013	12
640	1	3014	0
641	1	3015	2
641	1	3015	9
641	1	3015	11
641	1	3015	15
641	1	3015	16
641	1	3015	18
641	1	3015	21
641	1	3015	23
641	1	3015	24
641	1	3015	25
641	1	3016	2
641	1	3016	15
641	1	3016	16
641	1	3016	21
641	1	3017	0
642	1	3018	4
642	1	3018	6
642	1	3018	7
642	1	3018	8
642	1	3018	11
642	1	3018	12
642	1	3018	14
642	1	3018	18
642	1	3018	19
642	1	3018	22
642	1	3019	7
642	1	3019	8
642	1	3019	14
642	1	3019	19
642	1	3019	22
642	1	3020	8
642	1	3021	0
643	1	3022	1
643	1	3022	2
643	1	3022	3
643	1	3022	4
643	1	3022	5
643	1	3022	11
643	1	3022	18
643	1	3022	19
643	1	3022	22
643	1	3022	24
643	1	3023	1
643	1	3023	4
643	1	3023	5
643	1	3023	11
643	1	3023	19
643	1	3023	24
643	1	3024	5
643	1	3025	5
643	1	3026	0
644	1	3027	1
644	1	3027	2
644	1	3027	4
644	1	3027	7
644	1	3027	9
644	1	3027	10
644	1	3027	12
644	1	3027	16
644	1	3027	21
644	1	3027	24
644	1	3028	7
644	1	3028	9
644	1	3028	12
644	1	3028	16
644	1	3029	0
645	1	3030	2
645	1	3030	7
645	1	3030	9
645	1	3030	11
645	1	3030	12
645	1	3030	16
645	1	3030	19
645	1	3030	20
645	1	3030	21
645	1	3030	23
645	1	3031	16
645	1	3031	19
645	1	3031	21
645	1	3032	16
645	1	3032	21
645	1	3033	16
645	1	3033	21
645	1	3034	21
645	1	3035	0
646	1	3036	2
646	1	3036	3
646	1	3036	6
646	1	3036	10
646	1	3036	12
646	1	3036	15
646	1	3036	16
646	1	3036	19
646	1	3036	23
646	1	3036	24
646	1	3037	6
646	1	3037	19
646	1	3037	24
646	1	3038	6
646	1	3038	19
646	1	3039	0
647	1	3040	1
647	1	3040	6
647	1	3040	13
647	1	3040	15
647	1	3040	17
647	1	3040	19
647	1	3040	22
647	1	3040	23
647	1	3040	24
647	1	3040	25
647	1	3041	6
647	1	3041	17
647	1	3041	19
647	1	3041	23
647	1	3041	24
647	1	3042	6
647	1	3042	23
647	1	3043	6
647	1	3043	23
647	1	3044	23
647	1	3045	0
648	1	3046	2
648	1	3046	8
648	1	3046	9
648	1	3046	10
648	1	3046	11
648	1	3046	14
648	1	3046	16
648	1	3046	17
648	1	3046	19
648	1	3046	24
648	1	3047	16
648	1	3047	19
648	1	3048	0
649	1	3049	6
649	1	3049	10
649	1	3049	11
649	1	3049	16
649	1	3049	18
649	1	3049	21
649	1	3049	22
649	1	3049	23
649	1	3049	24
649	1	3049	25
649	1	3050	10
649	1	3050	11
649	1	3050	16
649	1	3051	16
649	1	3052	16
649	1	3053	0
650	1	3054	3
650	1	3054	5
650	1	3054	6
650	1	3054	7
650	1	3054	11
650	1	3054	12
650	1	3054	13
650	1	3054	16
650	1	3054	17
650	1	3054	25
650	1	3055	5
650	1	3055	6
650	1	3055	13
650	1	3055	16
650	1	3055	25
650	1	3056	6
650	1	3056	13
650	1	3057	6
650	1	3058	6
650	1	3059	6
650	1	3060	6
650	1	3061	6
650	1	3062	0
651	1	3063	1
651	1	3063	3
651	1	3063	6
651	1	3063	9
651	1	3063	11
651	1	3063	13
651	1	3063	15
651	1	3063	23
651	1	3063	24
651	1	3063	25
651	1	3064	1
651	1	3064	3
651	1	3064	9
651	1	3064	24
651	1	3065	3
651	1	3066	0
652	1	3067	3
652	1	3067	4
652	1	3067	6
652	1	3067	10
652	1	3067	12
652	1	3067	15
652	1	3067	16
652	1	3067	18
652	1	3067	23
652	1	3067	25
652	1	3068	15
652	1	3068	23
652	1	3069	0
653	1	3070	1
653	1	3070	2
653	1	3070	4
653	1	3070	6
653	1	3070	9
653	1	3070	12
653	1	3070	16
653	1	3070	17
653	1	3070	18
653	1	3070	22
653	1	3071	6
653	1	3071	9
653	1	3071	16
653	1	3071	18
653	1	3071	22
653	1	3072	9
653	1	3072	16
653	1	3072	18
653	1	3072	22
653	1	3073	18
653	1	3074	18
653	1	3075	18
653	1	3076	18
653	1	3077	0
654	1	3078	1
654	1	3078	3
654	1	3078	4
654	1	3078	5
654	1	3078	12
654	1	3078	16
654	1	3078	17
654	1	3078	18
654	1	3078	24
654	1	3078	25
654	1	3079	3
654	1	3079	17
654	1	3080	0
655	1	3081	3
655	1	3081	7
655	1	3081	8
655	1	3081	9
655	1	3081	11
655	1	3081	12
655	1	3081	14
655	1	3081	16
655	1	3081	20
655	1	3081	22
655	1	3082	8
655	1	3082	11
655	1	3082	14
655	1	3082	16
655	1	3082	20
655	1	3082	22
655	1	3083	14
655	1	3083	16
655	1	3083	22
655	1	3084	14
655	1	3085	0
656	1	3086	2
656	1	3086	8
656	1	3086	9
656	1	3086	10
656	1	3086	14
656	1	3086	15
656	1	3086	20
656	1	3086	22
656	1	3086	24
656	1	3086	25
656	1	3087	8
656	1	3087	9
656	1	3087	15
656	1	3087	20
656	1	3087	22
656	1	3088	8
656	1	3089	0
657	1	3090	2
657	1	3090	5
657	1	3090	6
657	1	3090	7
657	1	3090	9
657	1	3090	12
657	1	3090	15
657	1	3090	16
657	1	3090	20
657	1	3090	24
657	1	3091	6
657	1	3091	7
657	1	3091	12
657	1	3091	16
657	1	3092	7
657	1	3092	12
657	1	3092	16
657	1	3093	0
658	1	3094	1
658	1	3094	7
658	1	3094	9
658	1	3094	11
658	1	3094	16
658	1	3094	19
658	1	3094	20
658	1	3094	23
658	1	3094	24
658	1	3094	25
658	1	3095	9
658	1	3095	16
658	1	3095	20
658	1	3095	25
658	1	3096	0
659	1	3097	5
659	1	3097	6
659	1	3097	10
659	1	3097	11
659	1	3097	16
659	1	3097	19
659	1	3097	21
659	1	3097	22
659	1	3097	23
659	1	3097	24
659	1	3098	22
659	1	3098	23
659	1	3099	0
660	1	3100	5
660	1	3100	7
660	1	3100	11
660	1	3100	12
660	1	3100	13
660	1	3100	14
660	1	3100	17
660	1	3100	19
660	1	3100	23
660	1	3100	24
660	1	3101	5
660	1	3101	7
660	1	3101	13
660	1	3101	14
660	1	3102	5
660	1	3102	7
660	1	3103	0
661	1	3104	7
661	1	3104	11
661	1	3104	12
661	1	3104	14
661	1	3104	16
661	1	3104	18
661	1	3104	20
661	1	3104	21
661	1	3104	22
661	1	3104	23
661	1	3105	7
661	1	3105	11
661	1	3105	18
661	1	3105	20
661	1	3105	21
661	1	3106	11
661	1	3106	18
661	1	3107	11
661	1	3107	18
661	1	3108	0
662	1	3109	2
662	1	3109	4
662	1	3109	6
662	1	3109	7
662	1	3109	11
662	1	3109	13
662	1	3109	14
662	1	3109	22
662	1	3109	24
662	1	3109	25
662	1	3110	2
662	1	3110	7
662	1	3110	11
662	1	3110	22
662	1	3111	11
662	1	3112	0
663	1	3113	2
663	1	3113	4
663	1	3113	7
663	1	3113	10
663	1	3113	12
663	1	3113	13
663	1	3113	15
663	1	3113	17
663	1	3113	19
663	1	3113	20
663	1	3114	15
663	1	3114	17
663	1	3114	19
663	1	3114	20
663	1	3115	17
663	1	3115	19
663	1	3116	17
663	1	3117	0
664	1	3118	2
664	1	3118	3
664	1	3118	4
664	1	3118	5
664	1	3118	8
664	1	3118	9
664	1	3118	13
664	1	3118	16
664	1	3118	17
664	1	3118	20
664	1	3119	3
664	1	3119	5
664	1	3119	13
664	1	3119	17
664	1	3119	20
664	1	3120	20
664	1	3121	20
664	1	3122	20
664	1	3123	20
664	1	3124	0
665	1	3125	1
665	1	3125	2
665	1	3125	4
665	1	3125	7
665	1	3125	8
665	1	3125	11
665	1	3125	15
665	1	3125	22
665	1	3125	23
665	1	3125	25
665	1	3126	2
665	1	3126	8
665	1	3126	11
665	1	3126	15
665	1	3126	22
665	1	3127	8
665	1	3127	11
665	1	3128	0
666	1	3129	3
666	1	3129	5
666	1	3129	9
666	1	3129	10
666	1	3129	11
666	1	3129	12
666	1	3129	13
666	1	3129	20
666	1	3129	21
666	1	3129	24
666	1	3130	3
666	1	3130	11
666	1	3131	11
666	1	3132	0
667	1	3133	1
667	1	3133	3
667	1	3133	4
667	1	3133	7
667	1	3133	8
667	1	3133	13
667	1	3133	16
667	1	3133	18
667	1	3133	21
667	1	3133	23
667	1	3134	4
667	1	3134	16
667	1	3134	23
\.


--
-- Data for Name: concurso; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.concurso (id_tipo_jogo, nr_concurso, dt_concurso, vl_acumulado, nr_proximo_concurso, dt_proximo_concurso, nr_ganhador) FROM stdin;
1	3057	2024-03-19	1700000.00	3058	2024-03-20	2
1	3070	2024-04-04	1700000.00	3071	2024-04-05	1
1	3094	2024-05-03	1700000.00	3095	2024-05-04	1
1	3105	2024-05-16	1700000.00	3106	2024-05-17	2
1	3115	2024-05-28	1700000.00	3116	2024-05-29	6
1	3058	2024-03-20	1700000.00	3059	2024-03-21	3
1	3071	2024-04-05	1700000.00	3072	2024-04-06	18
1	3095	2024-05-04	1700000.00	3096	2024-05-06	1
1	3106	2024-05-17	1700000.00	3107	2024-05-18	1
1	3116	2024-05-29	1700000.00	3117	2024-05-31	1
1	3059	2024-03-21	5000000.00	3060	2024-03-22	1
1	3072	2024-04-06	1700000.00	3073	2024-04-08	2
1	3096	2024-05-06	1700000.00	3097	2024-05-07	2
1	3107	2024-05-18	1700000.00	3108	2024-05-20	1
1	3117	2024-05-31	1700000.00	3118	2024-06-01	4
1	3060	2024-03-22	1700000.00	3061	2024-03-23	8
1	3073	2024-04-08	1700000.00	3074	2024-04-09	3
1	3097	2024-05-07	4000000.00	3098	2024-05-08	0
1	3108	2024-05-20	1700000.00	3109	2024-05-21	1
1	3118	2024-06-01	1700000.00	3119	2024-06-03	1
1	3054	2024-03-15	1700000.00	3055	2024-03-16	2
1	3061	2024-03-23	1700000.00	3062	2024-03-25	1
1	3074	2024-04-09	1700000.00	3075	2024-04-10	1
1	3098	2024-05-08	1700000.00	3099	2024-05-09	2
1	3109	2024-05-21	5000000.00	3110	2024-05-22	1
1	3119	2024-06-03	5000000.00	3120	2024-06-04	2
1	3062	2024-03-25	1700000.00	3063	2024-03-26	1
1	3075	2024-04-10	1700000.00	3076	2024-04-11	1
1	3099	2024-05-09	6000000.00	3100	2024-05-10	0
1	3110	2024-05-22	1700000.00	3111	2024-05-23	5
1	3120	2024-06-04	1700000.00	3121	2024-06-05	2
1	3063	2024-03-26	1700000.00	3064	2024-03-27	1
1	3076	2024-04-11	1700000.00	3077	2024-04-12	2
1	3100	2024-05-10	1700000.00	3101	2024-05-11	3
1	3111	2024-05-23	1700000.00	3112	2024-05-24	1
1	3121	2024-06-05	1700000.00	3122	2024-06-06	4
1	3055	2024-03-16	1700000.00	3056	2024-03-18	1
1	3064	2024-03-27	4000000.00	3065	2024-03-28	0
1	3077	2024-04-12	1700000.00	3078	2024-04-13	2
1	3101	2024-05-11	1700000.00	3102	2024-05-13	2
1	3112	2024-05-24	1700000.00	3113	2024-05-25	1
1	3122	2024-06-06	4000000.00	3123	2024-06-07	0
1	3065	2024-03-28	8000000.00	3066	2024-03-30	0
1	3078	2024-04-13	4500000.00	3079	2024-04-15	0
1	3102	2024-05-13	4000000.00	3103	2024-05-14	0
1	3113	2024-05-25	1700000.00	3114	2024-05-27	4
1	3123	2024-06-07	1700000.00	3124	2024-06-08	3
1	3056	2024-03-18	4000000.00	3057	2024-03-19	0
1	3066	2024-03-30	12500000.00	3067	2024-04-01	0
1	3079	2024-04-15	6500000.00	3080	2024-04-16	1
1	3103	2024-05-14	1700000.00	3104	2024-05-15	1
1	3124	2024-06-08	4500000.00	3125	2024-06-10	0
1	3067	2024-04-01	1700000.00	3068	2024-04-02	20
1	3080	2024-04-16	1700000.00	3081	2024-04-17	6
1	3104	2024-05-15	1700000.00	3105	2024-05-16	2
1	3114	2024-05-27	1700000.00	3115	2024-05-28	1
1	3125	2024-06-10	8000000.00	3126	2024-06-11	0
1	3068	2024-04-02	4200000.00	3069	2024-04-03	0
1	3081	2024-04-17	1700000.00	3082	2024-04-18	2
1	3126	2024-06-11	1700000.00	3127	2024-06-12	3
1	3069	2024-04-03	6000000.00	3070	2024-04-04	3
1	3082	2024-04-18	1700000.00	3083	2024-04-19	1
1	3127	2024-06-12	1700000.00	3128	2024-06-13	1
1	3083	2024-04-19	1700000.00	3084	2024-04-20	2
1	3128	2024-06-13	1700000.00	3129	2024-06-14	2
1	3084	2024-04-20	4300000.00	3085	2024-04-22	0
1	3129	2024-06-14	6000000.00	3130	2024-06-15	1
1	3085	2024-04-22	1700000.00	3086	2024-04-23	2
1	3130	2024-06-15	1700000.00	3131	2024-06-17	5
1	3086	2024-04-23	3700000.00	3087	2024-04-24	0
1	3131	2024-06-17	1700000.00	3132	2024-06-18	2
1	3087	2024-04-24	1700000.00	3088	2024-04-25	4
1	3132	2024-06-18	1700000.00	3133	2024-06-19	1
1	3088	2024-04-25	1700000.00	3089	2024-04-26	5
1	3133	2024-06-19	1700000.00	3134	2024-06-20	2
1	3089	2024-04-26	4500000.00	3090	2024-04-27	1
1	3134	2024-06-20	1700000.00	3135	2024-06-21	3
1	3090	2024-04-27	1700000.00	3091	2024-04-29	7
1	2983	2023-12-19	1700000.00	2984	2023-12-20	3
1	2990	2023-12-28	1700000.00	2991	2023-12-29	5
1	2998	2024-01-08	4500000.00	2999	2024-01-09	0
1	3013	2024-01-25	1700000.00	3014	2024-01-26	1
1	3014	2024-01-26	1700000.00	3015	2024-01-27	4
1	3091	2024-04-29	1700000.00	3092	2024-04-30	1
1	3023	2024-02-06	1700000.00	3024	2024-02-07	3
1	3030	2024-02-16	1700000.00	3031	2024-02-17	3
1	3034	2024-02-21	4000000.00	3035	2024-02-22	0
1	3051	2024-03-12	1700000.00	3052	2024-03-13	5
1	3092	2024-04-30	1700000.00	3093	2024-05-02	1
1	1	2003-09-29	0.00	2	2003-10-06	5
1	2	2003-10-06	0.00	3	2003-10-13	1
1	3	2003-10-13	0.00	4	2003-10-20	2
1	4	2003-10-20	0.00	5	2003-10-27	1
1	5	2003-10-27	0.00	6	2003-11-03	2
1	6	2003-11-03	0.00	7	2003-11-10	2
1	7	2003-11-10	0.00	8	2003-11-17	9
1	8	2003-11-17	0.00	9	2003-11-24	1
1	9	2003-11-24	0.00	10	2003-12-01	3
1	10	2003-12-01	0.00	11	2003-12-08	0
1	11	2003-12-08	0.00	12	2003-12-15	0
1	12	2003-12-15	0.00	13	2003-12-22	1
1	13	2003-12-22	0.00	14	2003-12-29	3
1	14	2003-12-29	0.00	15	2004-01-05	3
1	15	2004-01-05	0.00	16	2004-01-12	22
1	16	2004-01-12	0.00	17	2004-01-19	9
1	17	2004-01-19	0.00	18	2004-01-26	1
1	18	2004-01-26	0.00	19	2004-02-02	3
1	19	2004-02-02	0.00	20	2004-02-09	10
1	20	2004-02-09	0.00	21	2004-02-16	9
1	21	2004-02-16	0.00	22	2004-02-25	3
1	22	2004-02-25	0.00	23	2004-03-01	1
1	23	2004-03-01	0.00	24	2004-03-08	1
1	24	2004-03-08	0.00	25	2004-03-15	2
1	25	2004-03-15	0.00	26	2004-03-22	0
1	26	2004-03-22	0.00	27	2004-03-29	3
1	27	2004-03-29	0.00	28	2004-04-05	2
1	28	2004-04-05	0.00	29	2004-04-12	2
1	29	2004-04-12	0.00	30	2004-04-19	5
1	30	2004-04-19	0.00	31	2004-04-26	2
1	31	2004-04-26	0.00	32	2004-05-03	3
1	32	2004-05-03	0.00	33	2004-05-10	2
1	33	2004-05-10	0.00	34	2004-05-17	9
1	34	2004-05-17	0.00	35	2004-05-24	0
1	35	2004-05-24	0.00	36	2004-05-31	1
1	36	2004-05-31	0.00	37	2004-06-07	6
1	37	2004-06-07	0.00	38	2004-06-14	1
1	38	2004-06-14	0.00	39	2004-06-21	0
1	39	2004-06-21	0.00	40	2004-06-28	3
1	40	2004-06-28	0.00	41	2004-07-05	9
1	41	2004-07-05	0.00	42	2004-07-12	5
1	42	2004-07-12	0.00	43	2004-07-19	1
1	43	2004-07-19	0.00	44	2004-07-26	2
1	44	2004-07-26	0.00	45	2004-08-02	0
1	45	2004-08-02	0.00	46	2004-08-09	4
1	46	2004-08-09	0.00	47	2004-08-16	4
1	47	2004-08-16	0.00	48	2004-08-23	16
1	48	2004-08-23	0.00	49	2004-08-30	2
1	49	2004-08-30	0.00	50	2004-09-06	0
1	50	2004-09-06	0.00	51	2004-09-13	1
1	51	2004-09-13	0.00	52	2004-09-20	2
1	52	2004-09-20	0.00	53	2004-09-27	3
1	53	2004-09-27	0.00	54	2004-10-04	4
1	54	2004-10-04	0.00	55	2004-10-11	27
1	55	2004-10-11	0.00	56	2004-10-18	6
1	56	2004-10-18	0.00	57	2004-10-25	0
1	57	2004-10-25	0.00	58	2004-11-01	1
1	58	2004-11-01	0.00	59	2004-11-08	6
1	59	2004-11-08	0.00	60	2004-11-16	2
1	60	2004-11-16	0.00	61	2004-11-22	3
1	61	2004-11-22	0.00	62	2004-11-29	2
1	62	2004-11-29	0.00	63	2004-12-06	5
1	63	2004-12-06	0.00	64	2004-12-13	2
1	64	2004-12-13	0.00	65	2004-12-20	4
1	65	2004-12-20	0.00	66	2004-12-27	0
1	66	2004-12-27	0.00	67	2005-01-03	8
1	67	2005-01-03	0.00	68	2005-01-10	4
1	68	2005-01-10	0.00	69	2005-01-17	2
1	69	2005-01-17	0.00	70	2005-01-24	4
1	70	2005-01-24	0.00	71	2005-01-31	6
1	71	2005-01-31	0.00	72	2005-02-09	4
1	72	2005-02-09	0.00	73	2005-02-14	2
1	73	2005-02-14	0.00	74	2005-02-21	3
1	74	2005-02-21	0.00	75	2005-02-28	7
1	75	2005-02-28	0.00	76	2005-03-07	2
1	76	2005-03-07	0.00	77	2005-03-14	13
1	77	2005-03-14	0.00	78	2005-03-21	4
1	78	2005-03-21	0.00	79	2005-03-28	1
1	79	2005-03-28	0.00	80	2005-04-04	1
1	80	2005-04-04	0.00	81	2005-04-11	1
1	81	2005-04-11	0.00	82	2005-04-18	6
1	82	2005-04-18	0.00	83	2005-04-25	4
1	83	2005-04-25	0.00	84	2005-05-02	3
1	84	2005-05-02	0.00	85	2005-05-09	2
1	85	2005-05-09	0.00	86	2005-05-16	13
1	86	2005-05-16	0.00	87	2005-05-23	14
1	87	2005-05-23	0.00	88	2005-05-30	14
1	88	2005-05-30	0.00	89	2005-06-06	5
1	89	2005-06-06	0.00	90	2005-06-13	2
1	90	2005-06-13	0.00	91	2005-06-20	4
1	91	2005-06-20	0.00	92	2005-06-27	2
1	92	2005-06-27	0.00	93	2005-07-04	5
1	93	2005-07-04	0.00	94	2005-07-11	6
1	94	2005-07-11	0.00	95	2005-07-18	2
1	95	2005-07-18	0.00	96	2005-07-25	2
1	96	2005-07-25	0.00	97	2005-08-02	1
1	97	2005-08-02	0.00	98	2005-08-08	4
1	98	2005-08-08	0.00	99	2005-08-15	5
1	99	2005-08-15	0.00	100	2005-08-22	4
1	100	2005-08-22	0.00	101	2005-08-29	6
1	101	2005-08-29	0.00	102	2005-09-05	9
1	102	2005-09-05	0.00	103	2005-09-12	5
1	103	2005-09-12	0.00	104	2005-09-19	5
1	104	2005-09-19	0.00	105	2005-09-26	2
1	105	2005-09-26	0.00	106	2005-10-03	2
1	106	2005-10-03	0.00	107	2005-10-10	3
1	107	2005-10-10	0.00	108	2005-10-17	1
1	108	2005-10-17	0.00	109	2005-10-24	8
1	109	2005-10-24	0.00	110	2005-10-31	14
1	110	2005-10-31	0.00	111	2005-11-07	2
1	111	2005-11-07	0.00	112	2005-11-14	1
1	112	2005-11-14	0.00	113	2005-11-21	1
1	113	2005-11-21	0.00	114	2005-11-28	3
1	114	2005-11-28	0.00	115	2005-12-05	0
1	115	2005-12-05	0.00	116	2005-12-12	1
1	116	2005-12-12	0.00	117	2005-12-19	2
1	117	2005-12-19	0.00	118	2005-12-27	3
1	118	2005-12-27	0.00	119	2006-01-02	4
1	119	2006-01-02	0.00	120	2006-01-09	1
1	120	2006-01-09	0.00	121	2006-01-16	2
1	121	2006-01-16	0.00	122	2006-01-23	3
1	122	2006-01-23	0.00	123	2006-01-30	8
1	123	2006-01-30	0.00	124	2006-02-06	4
1	124	2006-02-06	0.00	125	2006-02-13	2
1	125	2006-02-13	0.00	126	2006-02-20	2
1	126	2006-02-20	0.00	127	2006-03-01	0
1	127	2006-03-01	0.00	128	2006-03-06	5
1	128	2006-03-06	0.00	129	2006-03-13	2
1	129	2006-03-13	0.00	130	2006-03-20	3
1	130	2006-03-20	0.00	131	2006-03-27	3
1	131	2006-03-27	0.00	132	2006-04-03	1
1	132	2006-04-03	0.00	133	2006-04-10	10
1	133	2006-04-10	0.00	134	2006-04-17	5
1	134	2006-04-17	0.00	135	2006-04-24	4
1	135	2006-04-24	0.00	136	2006-05-02	7
1	136	2006-05-02	0.00	137	2006-05-08	2
1	137	2006-05-08	0.00	138	2006-05-15	2
1	138	2006-05-15	0.00	139	2006-05-22	3
1	139	2006-05-22	0.00	140	2006-05-29	1
1	140	2006-05-29	0.00	141	2006-06-05	7
1	141	2006-06-05	0.00	142	2006-06-12	2
1	142	2006-06-12	0.00	143	2006-06-19	1
1	143	2006-06-19	0.00	144	2006-06-26	5
1	144	2006-06-26	0.00	145	2006-07-03	36
1	145	2006-07-03	0.00	146	2006-07-10	3
1	146	2006-07-10	0.00	147	2006-07-17	6
1	147	2006-07-17	0.00	148	2006-07-24	3
1	148	2006-07-24	0.00	149	2006-07-31	17
1	149	2006-08-01	0.00	150	2006-08-07	5
1	150	2006-08-07	0.00	151	2006-08-14	1
1	151	2006-08-14	0.00	152	2006-08-21	5
1	152	2006-08-21	0.00	153	2006-08-28	3
1	153	2006-08-28	0.00	154	2006-09-04	8
1	154	2006-09-04	0.00	155	2006-09-11	1
1	155	2006-09-11	0.00	156	2006-09-18	0
1	156	2006-09-18	0.00	157	2006-09-25	7
1	157	2006-09-25	0.00	158	2006-10-02	9
1	158	2006-10-02	0.00	159	2006-10-09	2
1	159	2006-10-09	0.00	160	2006-10-16	2
1	160	2006-10-16	0.00	161	2006-10-19	3
1	161	2006-10-19	1800000.00	162	2006-10-23	0
1	162	2006-10-23	0.00	163	2006-10-26	5
1	163	2006-10-26	0.00	164	2006-10-30	3
1	164	2006-10-30	0.00	165	2006-11-03	1
1	165	2006-11-03	0.00	166	2006-11-06	2
1	166	2006-11-06	0.00	167	2006-11-09	39
1	167	2006-11-09	0.00	168	2006-11-13	3
1	168	2006-11-13	0.00	169	2006-11-16	1
1	169	2006-11-16	0.00	170	2006-11-21	0
1	170	2006-11-21	0.00	171	2006-11-23	1
1	171	2006-11-23	0.00	172	2006-11-27	4
1	172	2006-11-27	0.00	173	2006-11-30	1
1	173	2006-11-30	0.00	174	2006-12-04	0
1	174	2006-12-04	0.00	175	2006-12-07	11
1	175	2006-12-07	0.00	176	2006-12-11	2
1	176	2006-12-11	0.00	177	2006-12-14	1
1	177	2006-12-14	0.00	178	2006-12-18	2
1	178	2006-12-18	0.00	179	2006-12-21	1
1	179	2006-12-21	0.00	180	2006-12-26	6
1	180	2006-12-26	0.00	181	2006-12-28	13
1	181	2006-12-28	0.00	182	2007-01-02	2
1	182	2007-01-02	0.00	183	2007-01-04	7
1	183	2007-01-04	0.00	184	2007-01-08	4
1	184	2007-01-08	0.00	185	2007-01-11	3
1	185	2007-01-11	0.00	186	2007-01-15	3
1	186	2007-01-15	0.00	187	2007-01-18	2
1	187	2007-01-18	0.00	188	2007-01-22	2
1	188	2007-01-22	0.00	189	2007-01-25	6
1	189	2007-01-25	0.00	190	2007-01-29	2
1	190	2007-01-29	0.00	191	2007-02-01	3
1	191	2007-02-01	0.00	192	2007-02-05	1
1	192	2007-02-05	0.00	193	2007-02-08	3
1	193	2007-02-08	0.00	194	2007-02-12	2
1	194	2007-02-12	0.00	195	2007-02-15	1
1	195	2007-02-15	0.00	196	2007-02-22	10
1	196	2007-02-22	0.00	197	2007-02-26	1
1	197	2007-02-26	0.00	198	2007-03-01	4
1	198	2007-03-01	0.00	199	2007-03-05	3
1	199	2007-03-05	0.00	200	2007-03-08	1
1	200	2007-03-08	0.00	201	2007-03-12	2
1	201	2007-03-12	0.00	202	2007-03-15	4
1	202	2007-03-15	0.00	203	2007-03-19	0
1	203	2007-03-19	0.00	204	2007-03-22	15
1	204	2007-03-22	0.00	205	2007-03-26	4
1	205	2007-03-26	0.00	206	2007-03-29	1
1	206	2007-03-29	0.00	207	2007-04-02	2
1	207	2007-04-02	0.00	208	2007-04-05	1
1	208	2007-04-05	0.00	209	2007-04-09	2
1	209	2007-04-09	0.00	210	2007-04-12	3
1	210	2007-04-12	0.00	211	2007-04-16	2
1	211	2007-04-16	0.00	212	2007-04-19	12
1	212	2007-04-19	0.00	213	2007-04-23	3
1	213	2007-04-23	0.00	214	2007-04-26	0
1	214	2007-04-26	0.00	215	2007-04-30	2
1	215	2007-04-30	0.00	216	2007-05-03	4
1	216	2007-05-03	0.00	217	2007-05-07	3
1	217	2007-05-07	0.00	218	2007-05-10	2
1	218	2007-05-10	0.00	219	2007-05-14	1
1	219	2007-05-14	0.00	220	2007-05-17	1
1	220	2007-05-17	2500000.00	221	2007-05-21	0
1	221	2007-05-21	1000000.00	222	2007-05-24	2
1	222	2007-05-24	1000000.00	223	2007-05-28	1
1	223	2007-05-28	2500000.00	224	2007-05-31	0
1	224	2007-05-31	1400000.00	225	2007-06-04	4
1	225	2007-06-04	1000000.00	226	2007-06-08	3
1	226	2007-06-08	1000000.00	227	2007-06-11	1
1	227	2007-06-11	1000000.00	228	2007-06-14	3
1	228	2007-06-14	1000000.00	229	2007-06-18	7
1	229	2007-06-18	1000000.00	230	2007-06-21	3
1	230	2007-06-21	1100000.00	231	2007-06-25	1
1	231	2007-06-25	1100000.00	232	2007-06-28	1
1	232	2007-06-28	1100000.00	233	2007-07-02	1
1	233	2007-07-02	1000000.00	234	2007-07-05	8
1	234	2007-07-05	1000000.00	235	2007-07-09	1
1	235	2007-07-09	1000000.00	236	2007-07-12	4
1	236	2007-07-12	2500000.00	237	2007-07-16	0
1	237	2007-07-16	1000000.00	238	2007-07-19	5
1	238	2007-07-19	1000000.00	239	2007-07-23	1
1	239	2007-07-23	1000000.00	240	2007-07-26	4
1	240	2007-07-26	1000000.00	241	2007-07-30	1
1	241	2007-07-30	1000000.00	242	2007-08-02	6
1	242	2007-08-02	1000000.00	243	2007-08-06	2
1	243	2007-08-06	2800000.00	244	2007-08-09	0
1	244	2007-08-09	1200000.00	245	2007-08-13	4
1	245	2007-08-13	1000000.00	246	2007-08-16	1
1	246	2007-08-16	1000000.00	247	2007-08-20	2
1	247	2007-08-20	1000000.00	248	2007-08-23	1
1	248	2007-08-23	1200000.00	249	2007-08-27	5
1	249	2007-08-27	1000000.00	250	2007-08-30	4
1	250	2007-08-30	1200000.00	251	2007-09-03	1
1	251	2007-09-03	1200000.00	252	2007-09-06	3
1	252	2007-09-06	1000000.00	253	2007-09-10	1
1	253	2007-09-10	1000000.00	254	2007-09-13	3
1	254	2007-09-13	1200000.00	255	2007-09-17	4
1	255	2007-09-17	1200000.00	256	2007-09-20	3
1	256	2007-09-20	1200000.00	257	2007-09-24	6
1	257	2007-09-24	1200000.00	258	2007-09-27	2
1	258	2007-09-27	1200000.00	259	2007-10-01	6
1	259	2007-10-01	3000000.00	260	2007-10-04	0
1	260	2007-10-04	1200000.00	261	2007-10-08	1
1	261	2007-10-08	1200000.00	262	2007-10-11	2
1	262	2007-10-11	1100000.00	263	2007-10-15	1
1	263	2007-10-15	3000000.00	264	2007-10-18	0
1	264	2007-10-18	1200000.00	265	2007-10-22	6
1	265	2007-10-22	3000000.00	266	2007-10-25	0
1	266	2007-10-25	1200000.00	267	2007-10-29	5
1	267	2007-10-29	1300000.00	268	2007-11-01	2
1	268	2007-11-01	1200000.00	269	2007-11-05	1
1	269	2007-11-05	1300000.00	270	2007-11-08	1
1	270	2007-11-08	3000000.00	271	2007-11-12	0
1	271	2007-11-12	1200000.00	272	2007-11-16	6
1	272	2007-11-16	1200000.00	273	2007-11-19	6
1	273	2007-11-19	1300000.00	274	2007-11-22	2
1	274	2007-11-22	1200000.00	275	2007-11-26	4
1	275	2007-11-26	1000000.00	276	2007-11-29	2
1	276	2007-11-29	1400000.00	277	2007-12-03	3
1	277	2007-12-03	1000000.00	278	2007-12-06	4
1	278	2007-12-06	1000000.00	279	2007-12-10	25
1	279	2007-12-10	1000000.00	280	2007-12-13	3
1	280	2007-12-13	1200000.00	281	2007-12-17	7
1	281	2007-12-17	1000000.00	282	2007-12-20	6
1	282	2007-12-20	1000000.00	283	2007-12-22	5
1	283	2007-12-22	1000000.00	284	2007-12-27	5
1	284	2007-12-27	1200000.00	285	2007-12-29	7
1	285	2007-12-29	1300000.00	286	2008-01-03	3
1	286	2008-01-03	1200000.00	287	2008-01-07	3
1	287	2008-01-07	1200000.00	288	2008-01-10	5
1	288	2008-01-10	1200000.00	289	2008-01-14	1
1	289	2008-01-14	1300000.00	290	2008-01-17	14
1	290	2008-01-17	1200000.00	291	2008-01-21	5
1	291	2008-01-21	1300000.00	292	2008-01-24	5
1	292	2008-01-24	1200000.00	293	2008-01-28	1
1	293	2008-01-28	1200000.00	294	2008-01-31	3
1	294	2008-01-31	1300000.00	295	2008-02-07	3
1	295	2008-02-07	1200000.00	296	2008-02-11	2
1	296	2008-02-11	1200000.00	297	2008-02-14	5
1	297	2008-02-14	3000000.00	298	2008-02-18	0
1	298	2008-02-18	1200000.00	299	2008-02-21	2
1	299	2008-02-21	1200000.00	300	2008-02-25	1
1	300	2008-02-25	1200000.00	301	2008-02-28	5
1	301	2008-02-28	1200000.00	302	2008-03-03	4
1	302	2008-03-03	1200000.00	303	2008-03-06	9
1	303	2008-03-06	1200000.00	304	2008-03-10	3
1	304	2008-03-10	3000000.00	305	2008-03-13	0
1	305	2008-03-13	1200000.00	306	2008-03-17	3
1	306	2008-03-17	2700000.00	307	2008-03-20	0
1	307	2008-03-20	1100000.00	308	2008-03-24	22
1	308	2008-03-24	1200000.00	309	2008-03-27	2
1	309	2008-03-27	1200000.00	310	2008-03-31	2
1	310	2008-03-31	1100000.00	311	2008-04-03	1
1	311	2008-04-03	1200000.00	312	2008-04-07	9
1	312	2008-04-07	1200000.00	313	2008-04-10	1
1	313	2008-04-10	1200000.00	314	2008-04-14	3
1	314	2008-04-14	1200000.00	315	2008-04-17	1
1	315	2008-04-17	1200000.00	316	2008-04-22	10
1	316	2008-04-22	1100000.00	317	2008-04-24	1
1	317	2008-04-24	1100000.00	318	2008-04-28	3
1	318	2008-04-28	1200000.00	319	2008-05-02	4
1	319	2008-05-02	1100000.00	320	2008-05-05	7
1	320	2008-05-05	1200000.00	321	2008-05-08	3
1	321	2008-05-08	1200000.00	322	2008-05-12	1
1	322	2008-05-12	1200000.00	323	2008-05-15	2
1	323	2008-05-15	1200000.00	324	2008-05-19	1
1	324	2008-05-19	1200000.00	325	2008-05-23	4
1	325	2008-05-23	2500000.00	326	2008-05-26	0
1	326	2008-05-26	1100000.00	327	2008-05-29	3
1	327	2008-05-29	1200000.00	328	2008-06-02	4
1	328	2008-06-02	1200000.00	329	2008-06-05	2
1	329	2008-06-05	1100000.00	330	2008-06-09	5
1	330	2008-06-09	1300000.00	331	2008-06-12	5
1	331	2008-06-12	1200000.00	332	2008-06-16	7
1	332	2008-06-16	1300000.00	333	2008-06-19	4
1	333	2008-06-19	1200000.00	334	2008-06-23	13
1	334	2008-06-23	1100000.00	335	2008-06-26	5
1	335	2008-06-26	1200000.00	336	2008-06-30	3
1	336	2008-06-30	1100000.00	337	2008-07-03	7
1	337	2008-07-03	1300000.00	338	2008-07-07	3
1	338	2008-07-07	1300000.00	339	2008-07-10	2
1	339	2008-07-10	1300000.00	340	2008-07-14	4
1	340	2008-07-14	1300000.00	341	2008-07-17	1
1	341	2008-07-17	1300000.00	342	2008-07-21	1
1	342	2008-07-21	1300000.00	343	2008-07-24	3
1	343	2008-07-24	1300000.00	344	2008-07-28	1
1	344	2008-07-28	1300000.00	345	2008-07-31	3
1	345	2008-07-31	1200000.00	346	2008-08-04	2
1	346	2008-08-04	1300000.00	347	2008-08-07	9
1	347	2008-08-07	1000000.00	348	2008-08-11	1
1	348	2008-08-11	1300000.00	349	2008-08-14	3
1	349	2008-08-14	1200000.00	350	2008-08-18	32
1	350	2008-08-18	1200000.00	351	2008-08-21	6
1	351	2008-08-21	1100000.00	352	2008-08-25	2
1	352	2008-08-25	1100000.00	353	2008-08-28	2
1	353	2008-08-28	1300000.00	354	2008-09-01	14
1	354	2008-09-01	1300000.00	355	2008-09-04	1
1	355	2008-09-04	1300000.00	356	2008-09-08	4
1	356	2008-09-08	1200000.00	357	2008-09-11	2
1	357	2008-09-11	1300000.00	358	2008-09-15	6
1	358	2008-09-15	1200000.00	359	2008-09-18	2
1	359	2008-09-18	1300000.00	360	2008-09-22	1
1	360	2008-09-22	1300000.00	361	2008-09-25	2
1	361	2008-09-25	1300000.00	362	2008-09-29	4
1	362	2008-09-29	1300000.00	363	2008-10-02	8
1	363	2008-10-02	1300000.00	364	2008-10-06	5
1	364	2008-10-06	1300000.00	365	2008-10-09	3
1	365	2008-10-09	1400000.00	366	2008-10-13	2
1	366	2008-10-13	1300000.00	367	2008-10-16	16
1	367	2008-10-16	1300000.00	368	2008-10-20	39
1	368	2008-10-20	1300000.00	369	2008-10-23	2
1	369	2008-10-23	1300000.00	370	2008-10-27	1
1	370	2008-10-27	1300000.00	371	2008-10-30	5
1	371	2008-10-30	3000000.00	372	2008-11-03	0
1	372	2008-11-03	1300000.00	373	2008-11-06	6
1	373	2008-11-06	1300000.00	374	2008-11-10	4
1	374	2008-11-10	1300000.00	375	2008-11-13	3
1	375	2008-11-13	1300000.00	376	2008-11-17	4
1	376	2008-11-17	1200000.00	377	2008-11-20	1
1	377	2008-11-20	1300000.00	378	2008-11-24	2
1	378	2008-11-24	1200000.00	379	2008-11-27	2
1	379	2008-11-27	1400000.00	380	2008-12-01	1
1	380	2008-12-01	1300000.00	381	2008-12-04	1
1	381	2008-12-04	1300000.00	382	2008-12-08	17
1	382	2008-12-08	1300000.00	383	2008-12-11	2
1	383	2008-12-11	1300000.00	384	2008-12-15	4
1	384	2008-12-15	1300000.00	385	2008-12-18	3
1	385	2008-12-18	1300000.00	386	2008-12-22	7
1	386	2008-12-22	1200000.00	387	2008-12-26	3
1	387	2008-12-26	1300000.00	388	2008-12-29	11
1	388	2008-12-29	2800000.00	389	2009-01-02	0
1	389	2009-01-02	1300000.00	390	2009-01-05	5
1	390	2009-01-05	1300000.00	391	2009-01-08	2
1	391	2009-01-08	1400000.00	392	2009-01-12	16
1	392	2009-01-12	3000000.00	393	2009-01-15	0
1	393	2009-01-15	1300000.00	394	2009-01-19	3
1	394	2009-01-19	1300000.00	395	2009-01-22	4
1	395	2009-01-22	1300000.00	396	2009-01-26	6
1	396	2009-01-26	1300000.00	397	2009-01-29	12
1	397	2009-01-29	1300000.00	398	2009-02-02	3
1	398	2009-02-02	1300000.00	399	2009-02-05	3
1	399	2009-02-05	1300000.00	400	2009-02-09	6
1	400	2009-02-09	1300000.00	401	2009-02-12	2
1	401	2009-02-12	1300000.00	402	2009-02-16	4
1	402	2009-02-16	1300000.00	403	2009-02-19	3
1	403	2009-02-19	1300000.00	404	2009-02-26	1
1	404	2009-02-26	1300000.00	405	2009-03-02	10
1	405	2009-03-02	1300000.00	406	2009-03-05	4
1	406	2009-03-05	1300000.00	407	2009-03-09	2
1	407	2009-03-09	1300000.00	408	2009-03-12	3
1	408	2009-03-12	1300000.00	409	2009-03-16	6
1	409	2009-03-16	1400000.00	410	2009-03-19	7
1	410	2009-03-19	1300000.00	411	2009-03-23	3
1	411	2009-03-23	1300000.00	412	2009-03-26	4
1	412	2009-03-26	1500000.00	413	2009-03-30	1
1	413	2009-03-30	1200000.00	414	2009-04-02	4
1	414	2009-04-02	1300000.00	415	2009-04-06	1
1	415	2009-04-06	1300000.00	416	2009-04-09	5
1	416	2009-04-09	1300000.00	417	2009-04-13	4
1	417	2009-04-15	1100000.00	418	2009-04-16	1
1	418	2009-04-16	1200000.00	419	2009-04-20	4
1	419	2009-04-20	1300000.00	420	2009-04-23	10
1	420	2009-04-23	1200000.00	421	2009-04-27	3
1	421	2009-04-27	1300000.00	422	2009-04-30	2
1	422	2009-04-30	1300000.00	423	2009-05-04	11
1	423	2009-05-04	1300000.00	424	2009-05-07	1
1	424	2009-05-07	3500000.00	425	2009-05-11	0
1	425	2009-05-11	1300000.00	426	2009-05-14	6
1	426	2009-05-14	1300000.00	427	2009-05-18	2
1	427	2009-05-18	1200000.00	428	2009-05-21	2
1	428	2009-05-21	1300000.00	429	2009-05-25	2
1	429	2009-05-25	1300000.00	430	2009-05-28	7
1	430	2009-05-28	1300000.00	431	2009-06-01	1
1	431	2009-06-01	1300000.00	432	2009-06-04	3
1	432	2009-06-04	1400000.00	433	2009-06-08	12
1	433	2009-06-08	1300000.00	434	2009-06-12	4
1	434	2009-06-12	1200000.00	435	2009-06-15	3
1	435	2009-06-15	1300000.00	436	2009-06-18	2
1	436	2009-06-18	1600000.00	437	2009-06-22	4
1	437	2009-06-22	1400000.00	438	2009-06-25	1
1	438	2009-06-25	1300000.00	439	2009-06-29	2
1	439	2009-06-29	1300000.00	440	2009-07-02	3
1	440	2009-07-02	1400000.00	441	2009-07-06	4
1	441	2009-07-06	1300000.00	442	2009-07-09	1
1	442	2009-07-09	1300000.00	443	2009-07-13	8
1	443	2009-07-13	1300000.00	444	2009-07-16	4
1	444	2009-07-16	1400000.00	445	2009-07-20	4
1	445	2009-07-20	1400000.00	446	2009-07-23	4
1	446	2009-07-23	1600000.00	447	2009-07-27	5
1	447	2009-07-27	1300000.00	448	2009-07-30	3
1	448	2009-07-30	1300000.00	449	2009-08-03	1
1	449	2009-08-03	3300000.00	450	2009-08-06	0
1	450	2009-08-06	1600000.00	451	2009-08-10	3
1	451	2009-08-10	1400000.00	452	2009-08-13	9
1	452	2009-08-13	3500000.00	453	2009-08-17	0
1	453	2009-08-17	1500000.00	454	2009-08-20	4
1	454	2009-08-20	3500000.00	455	2009-08-24	0
1	455	2009-08-24	1500000.00	456	2009-08-27	8
1	456	2009-08-27	1100000.00	457	2009-08-31	7
1	457	2009-08-31	1500000.00	458	2009-09-03	1
1	458	2009-09-03	1400000.00	459	2009-09-08	5
1	459	2009-09-08	1400000.00	460	2009-09-10	3
1	460	2009-09-10	1400000.00	461	2009-09-14	8
1	461	2009-09-14	1400000.00	462	2009-09-17	5
1	462	2009-09-17	4000000.00	463	2009-09-21	0
1	463	2009-09-21	1500000.00	464	2009-09-24	7
1	464	2009-09-24	2000000.00	465	2009-09-28	2
1	465	2009-09-28	1500000.00	466	2009-10-01	2
1	466	2009-10-01	1700000.00	467	2009-10-05	1
1	467	2009-10-05	2000000.00	468	2009-10-08	5
1	468	2009-10-08	1600000.00	469	2009-10-13	8
1	469	2009-10-13	1600000.00	470	2009-10-15	3
1	470	2009-10-15	1400000.00	471	2009-10-19	3
1	471	2009-10-19	1200000.00	472	2009-10-22	1
1	472	2009-10-22	1600000.00	473	2009-10-26	3
1	473	2009-10-27	1500000.00	474	2009-10-29	8
1	474	2009-10-29	1500000.00	475	2009-11-03	2
1	475	2009-11-03	2500000.00	476	2009-11-05	0
1	476	2009-11-05	1600000.00	477	2009-11-09	1
1	477	2009-11-09	1500000.00	478	2009-11-12	8
1	478	2009-11-12	1500000.00	479	2009-11-16	7
1	479	2009-11-16	1500000.00	480	2009-11-19	1
1	480	2009-11-19	1000000.00	481	2009-11-23	2
1	481	2009-11-23	1500000.00	482	2009-11-26	7
1	482	2009-11-26	1500000.00	483	2009-11-30	4
1	483	2009-11-30	1500000.00	484	2009-12-03	5
1	484	2009-12-03	1600000.00	485	2009-12-07	3
1	485	2009-12-07	1500000.00	486	2009-12-10	2
1	486	2009-12-10	1500000.00	487	2009-12-14	3
1	487	2009-12-14	1500000.00	488	2009-12-17	5
1	488	2009-12-17	1400000.00	489	2009-12-21	6
1	489	2009-12-21	1400000.00	490	2009-12-24	1
1	490	2009-12-24	1200000.00	491	2009-12-28	3
1	491	2009-12-28	1200000.00	492	2009-12-31	10
1	492	2009-12-31	1000000.00	493	2010-01-04	2
1	493	2010-01-04	1200000.00	494	2010-01-07	1
1	494	2010-01-07	1500000.00	495	2010-01-11	1
1	495	2010-01-11	1300000.00	496	2010-01-14	14
1	496	2010-01-14	1500000.00	497	2010-01-18	4
1	497	2010-01-18	1500000.00	498	2010-01-21	1
1	498	2010-01-21	1400000.00	499	2010-01-25	1
1	499	2010-01-25	1300000.00	500	2010-01-28	5
1	500	2010-01-28	1500000.00	501	2010-02-01	11
1	501	2010-02-01	1400000.00	502	2010-02-04	9
1	502	2010-02-04	1400000.00	503	2010-02-08	2
1	503	2010-02-08	1300000.00	504	2010-02-11	3
1	504	2010-02-11	2700000.00	505	2010-02-13	0
1	505	2010-02-13	1000000.00	506	2010-02-18	1
1	506	2010-02-18	1500000.00	507	2010-02-22	1
1	507	2010-02-22	1500000.00	508	2010-02-25	6
1	508	2010-02-25	1400000.00	509	2010-03-01	5
1	509	2010-03-01	1500000.00	510	2010-03-04	9
1	510	2010-03-04	1500000.00	511	2010-03-08	4
1	511	2010-03-08	1500000.00	512	2010-03-11	5
1	512	2010-03-12	1500000.00	513	2010-03-15	1
1	513	2010-03-15	1500000.00	514	2010-03-18	5
1	514	2010-03-18	1500000.00	515	2010-03-22	2
1	515	2010-03-22	1500000.00	516	2010-03-25	6
1	516	2010-03-25	1500000.00	517	2010-03-29	1
1	517	2010-03-29	1400000.00	518	2010-04-01	1
1	518	2010-04-01	1500000.00	519	2010-04-05	1
1	519	2010-04-05	1400000.00	520	2010-04-08	8
1	520	2010-04-08	1500000.00	521	2010-04-12	5
1	521	2010-04-12	1500000.00	522	2010-04-15	4
1	522	2010-04-15	1500000.00	523	2010-04-19	1
1	523	2010-04-19	1300000.00	524	2010-04-22	2
1	524	2010-04-22	1500000.00	525	2010-04-26	4
1	525	2010-04-26	1500000.00	526	2010-04-29	4
1	526	2010-04-29	1200000.00	527	2010-05-03	4
1	527	2010-05-03	1300000.00	528	2010-05-06	3
1	528	2010-05-06	1400000.00	529	2010-05-10	1
1	529	2010-05-10	1300000.00	530	2010-05-13	1
1	530	2010-05-13	1500000.00	531	2010-05-17	2
1	531	2010-05-17	1300000.00	532	2010-05-20	1
1	532	2010-05-20	1500000.00	533	2010-05-24	4
1	533	2010-05-24	1400000.00	534	2010-05-27	2
1	534	2010-05-27	1300000.00	535	2010-05-31	8
1	535	2010-05-31	1500000.00	536	2010-06-04	8
1	536	2010-06-04	1500000.00	537	2010-06-07	3
1	537	2010-06-07	1500000.00	538	2010-06-10	3
1	538	2010-06-10	1500000.00	539	2010-06-14	2
1	539	2010-06-14	1100000.00	540	2010-06-17	2
1	540	2010-06-17	1500000.00	541	2010-06-21	2
1	541	2010-06-21	1500000.00	542	2010-06-24	13
1	542	2010-06-24	1300000.00	543	2010-06-28	2
1	543	2010-06-28	1300000.00	544	2010-07-01	1
1	544	2010-07-01	1500000.00	545	2010-07-05	8
1	545	2010-07-05	1200000.00	546	2010-07-08	5
1	546	2010-07-08	1300000.00	547	2010-07-12	10
1	547	2010-07-12	1200000.00	548	2010-07-15	4
1	548	2010-07-15	1500000.00	549	2010-07-19	3
1	549	2010-07-19	1500000.00	550	2010-07-22	3
1	550	2010-07-22	3500000.00	551	2010-07-26	0
1	551	2010-07-26	1500000.00	552	2010-07-29	4
1	552	2010-07-29	1200000.00	553	2010-08-02	5
1	553	2010-08-02	1200000.00	554	2010-08-05	6
1	554	2010-08-05	1500000.00	555	2010-08-09	2
1	555	2010-08-09	1500000.00	556	2010-08-12	2
1	556	2010-08-12	1500000.00	557	2010-08-16	1
1	557	2010-08-16	1500000.00	558	2010-08-19	8
1	558	2010-08-19	1500000.00	559	2010-08-23	4
1	559	2010-08-23	1400000.00	560	2010-08-26	8
1	560	2010-08-26	1500000.00	561	2010-08-30	4
1	561	2010-08-30	1500000.00	562	2010-09-02	2
1	562	2010-09-02	3500000.00	563	2010-09-06	0
1	563	2010-09-06	1400000.00	564	2010-09-09	1
1	564	2010-09-09	1500000.00	565	2010-09-13	6
1	565	2010-09-13	1500000.00	566	2010-09-16	4
1	566	2010-09-16	1400000.00	567	2010-09-20	1
1	567	2010-09-20	1500000.00	568	2010-09-23	1
1	568	2010-09-23	1500000.00	569	2010-09-27	2
1	569	2010-09-27	1500000.00	570	2010-09-30	3
1	570	2010-09-30	1100000.00	571	2010-10-04	5
1	571	2010-10-04	1500000.00	572	2010-10-07	1
1	572	2010-10-07	1300000.00	573	2010-10-11	8
1	573	2010-10-11	1500000.00	574	2010-10-14	10
1	574	2010-10-14	1300000.00	575	2010-10-18	2
1	575	2010-10-18	1500000.00	576	2010-10-21	3
1	576	2010-10-21	1500000.00	577	2010-10-25	2
1	577	2010-10-25	1500000.00	578	2010-10-28	2
1	578	2010-10-28	1300000.00	579	2010-11-01	2
1	579	2010-11-01	1500000.00	580	2010-11-04	4
1	580	2010-11-04	1400000.00	581	2010-11-08	4
1	581	2010-11-08	1500000.00	582	2010-11-11	8
1	582	2010-11-11	1000000.00	583	2010-11-16	5
1	583	2010-11-16	1300000.00	584	2010-11-18	1
1	584	2010-11-18	1500000.00	585	2010-11-22	3
1	585	2010-11-22	1500000.00	586	2010-11-25	3
1	586	2010-11-25	1500000.00	587	2010-11-29	7
1	587	2010-11-29	1500000.00	588	2010-12-02	4
1	588	2010-12-02	1500000.00	589	2010-12-06	2
1	589	2010-12-06	1600000.00	590	2010-12-09	3
1	590	2010-12-09	1500000.00	591	2010-12-13	2
1	591	2010-12-13	1500000.00	592	2010-12-16	3
1	592	2010-12-16	3900000.00	593	2010-12-20	0
1	593	2010-12-20	1500000.00	594	2010-12-23	4
1	594	2010-12-23	1000000.00	595	2010-12-27	4
1	595	2010-12-27	1500000.00	596	2010-12-30	3
1	596	2010-12-30	1200000.00	597	2011-01-03	7
1	597	2011-01-03	1500000.00	598	2011-01-06	5
1	598	2011-01-06	1500000.00	599	2011-01-10	2
1	599	2011-01-10	1300000.00	600	2011-01-13	2
1	600	2011-01-13	1500000.00	601	2011-01-17	1
1	601	2011-01-17	1600000.00	602	2011-01-20	1
1	602	2011-01-20	1300000.00	603	2011-01-24	3
1	603	2011-01-24	1300000.00	604	2011-01-27	9
1	604	2011-01-27	1500000.00	605	2011-01-31	3
1	605	2011-01-31	1500000.00	606	2011-02-03	2
1	606	2011-02-03	1300000.00	607	2011-02-07	2
1	607	2011-02-07	1300000.00	608	2011-02-10	3
1	608	2011-02-10	1500000.00	609	2011-02-14	3
1	609	2011-02-14	1500000.00	610	2011-02-17	2
1	610	2011-02-17	1100000.00	611	2011-02-21	2
1	611	2011-02-21	1300000.00	612	2011-02-24	2
1	612	2011-02-24	1200000.00	613	2011-02-28	3
1	613	2011-02-28	1400000.00	614	2011-03-03	1
1	614	2011-03-03	1000000.00	615	2011-03-05	1
1	615	2011-03-05	2600000.00	616	2011-03-10	0
1	616	2011-03-10	1500000.00	617	2011-03-14	2
1	617	2011-03-14	4000000.00	618	2011-03-17	0
1	618	2011-03-17	1500000.00	619	2011-03-21	6
1	619	2011-03-21	1500000.00	620	2011-03-24	6
1	620	2011-03-24	1500000.00	621	2011-03-28	3
1	621	2011-03-28	1500000.00	622	2011-03-31	3
1	622	2011-03-31	1300000.00	623	2011-04-04	5
1	623	2011-04-04	1600000.00	624	2011-04-07	2
1	624	2011-04-07	1500000.00	625	2011-04-11	6
1	625	2011-04-11	1500000.00	626	2011-04-14	3
1	626	2011-04-14	1500000.00	627	2011-04-18	5
1	627	2011-04-18	1600000.00	628	2011-04-20	4
1	628	2011-04-20	1400000.00	629	2011-04-25	4
1	629	2011-04-25	1500000.00	630	2011-04-28	8
1	630	2011-04-28	1500000.00	631	2011-05-02	2
1	631	2011-05-02	1600000.00	632	2011-05-05	3
1	632	2011-05-05	1600000.00	633	2011-05-09	4
1	633	2011-05-09	1500000.00	634	2011-05-12	2
1	634	2011-05-12	1600000.00	635	2011-05-16	3
1	635	2011-05-16	1500000.00	636	2011-05-19	2
1	636	2011-05-19	1500000.00	637	2011-05-23	3
1	637	2011-05-23	1600000.00	638	2011-05-26	2
1	638	2011-05-26	1500000.00	639	2011-05-30	2
1	639	2011-05-30	1600000.00	640	2011-06-02	5
1	640	2011-06-02	1600000.00	641	2011-06-06	2
1	641	2011-06-06	1300000.00	642	2011-06-09	1
1	642	2011-06-09	1600000.00	643	2011-06-13	4
1	643	2011-06-13	1600000.00	644	2011-06-16	3
1	644	2011-06-16	1600000.00	645	2011-06-20	2
1	645	2011-06-20	1300000.00	646	2011-06-24	4
1	646	2011-06-24	3500000.00	647	2011-06-27	0
1	647	2011-06-27	1600000.00	648	2011-06-30	3
1	648	2011-06-30	1600000.00	649	2011-07-04	11
1	649	2011-07-04	1600000.00	650	2011-07-07	2
1	650	2011-07-07	1600000.00	651	2011-07-11	7
1	651	2011-07-11	1600000.00	652	2011-07-14	6
1	652	2011-07-14	1600000.00	653	2011-07-18	8
1	653	2011-07-18	1600000.00	654	2011-07-21	5
1	654	2011-07-21	1600000.00	655	2011-07-25	2
1	655	2011-07-25	1600000.00	656	2011-07-28	1
1	656	2011-07-28	1700000.00	657	2011-08-01	11
1	657	2011-08-01	1800000.00	658	2011-08-04	9
1	658	2011-08-04	4000000.00	659	2011-08-08	0
1	659	2011-08-08	1800000.00	660	2011-08-11	6
1	660	2011-08-11	4600000.00	661	2011-08-15	0
1	661	2011-08-15	7000000.00	662	2011-08-18	0
1	662	2011-08-18	1800000.00	663	2011-08-22	8
1	663	2011-08-22	1700000.00	664	2011-08-25	8
1	664	2011-08-25	2000000.00	665	2011-08-29	3
1	665	2011-08-29	1800000.00	666	2011-09-01	4
1	666	2011-09-01	1700000.00	667	2011-09-05	3
1	667	2011-09-05	4000000.00	668	2011-09-08	0
1	668	2011-09-08	6300000.00	669	2011-09-12	0
1	669	2011-09-13	1500000.00	670	2011-09-15	3
1	670	2011-09-15	1800000.00	671	2011-09-19	1
1	671	2011-09-19	1800000.00	672	2011-09-22	5
1	672	2011-09-22	1700000.00	673	2011-09-26	18
1	673	2011-09-26	1500000.00	674	2011-09-29	6
1	674	2011-09-29	1500000.00	675	2011-10-03	3
1	675	2011-10-03	4500000.00	676	2011-10-06	0
1	676	2011-10-06	2000000.00	677	2011-10-10	27
1	677	2011-10-10	1500000.00	678	2011-10-13	4
1	678	2011-10-13	1500000.00	679	2011-10-17	7
1	679	2011-10-17	1800000.00	680	2011-10-20	3
1	680	2011-10-20	1800000.00	681	2011-10-24	6
1	681	2011-10-24	1800000.00	682	2011-10-27	11
1	682	2011-10-27	1500000.00	683	2011-10-31	5
1	683	2011-10-31	1800000.00	684	2011-11-03	3
1	684	2011-11-03	1800000.00	685	2011-11-07	2
1	685	2011-11-07	2000000.00	686	2011-11-10	6
1	686	2011-11-10	2000000.00	687	2011-11-14	8
1	687	2011-11-14	1700000.00	688	2011-11-17	3
1	688	2011-11-17	1600000.00	689	2011-11-21	3
1	689	2011-11-21	1800000.00	690	2011-11-24	5
1	690	2011-11-24	1800000.00	691	2011-11-28	13
1	691	2011-11-28	1800000.00	692	2011-12-01	3
1	692	2011-12-01	1800000.00	693	2011-12-05	7
1	693	2011-12-05	1800000.00	694	2011-12-08	1
1	694	2011-12-08	1800000.00	695	2011-12-12	2
1	695	2011-12-12	1800000.00	696	2011-12-15	1
1	696	2011-12-15	1800000.00	697	2011-12-19	4
1	697	2011-12-19	1800000.00	698	2011-12-22	5
1	698	2011-12-22	1800000.00	699	2011-12-26	8
1	699	2011-12-26	1800000.00	700	2011-12-29	1
1	700	2011-12-29	4500000.00	701	2012-01-02	0
1	701	2012-01-02	1800000.00	702	2012-01-05	3
1	702	2012-01-05	1800000.00	703	2012-01-09	10
1	703	2012-01-09	1800000.00	704	2012-01-12	6
1	704	2012-01-12	1800000.00	705	2012-01-16	6
1	705	2012-01-16	1800000.00	706	2012-01-19	2
1	706	2012-01-19	1800000.00	707	2012-01-23	4
1	707	2012-01-23	1800000.00	708	2012-01-26	3
1	708	2012-01-26	1800000.00	709	2012-01-30	5
1	709	2012-01-30	1800000.00	710	2012-02-02	4
1	710	2012-02-02	1800000.00	711	2012-02-06	2
1	711	2012-02-06	1500000.00	712	2012-02-08	5
1	712	2012-02-08	1200000.00	713	2012-02-10	1
1	713	2012-02-10	1800000.00	714	2012-02-13	2
1	714	2012-02-13	1800000.00	715	2012-02-15	3
1	715	2012-02-15	1500000.00	716	2012-02-17	6
1	716	2012-02-17	1500000.00	717	2012-02-22	15
1	717	2012-02-22	1500000.00	718	2012-02-24	9
1	718	2012-02-24	1500000.00	719	2012-02-27	10
1	719	2012-02-27	1500000.00	720	2012-02-29	2
1	720	2012-03-01	1500000.00	721	2012-03-02	2
1	721	2012-03-02	1500000.00	722	2012-03-05	2
1	722	2012-03-05	1500000.00	723	2012-03-07	5
1	723	2012-03-07	1500000.00	724	2012-03-09	2
1	724	2012-03-09	1500000.00	725	2012-03-12	8
1	725	2012-03-12	1500000.00	726	2012-03-14	1
1	726	2012-03-14	1500000.00	727	2012-03-16	2
1	727	2012-03-16	1500000.00	728	2012-03-19	2
1	728	2012-03-19	1500000.00	729	2012-03-21	2
1	729	2012-03-21	3500000.00	730	2012-03-23	0
1	730	2012-03-23	1500000.00	731	2012-03-26	2
1	731	2012-03-26	1500000.00	732	2012-03-28	8
1	732	2012-03-28	1500000.00	733	2012-03-30	2
1	733	2012-03-30	1500000.00	734	2012-04-02	4
1	734	2012-04-02	1500000.00	735	2012-04-04	7
1	735	2012-04-04	1500000.00	736	2012-04-07	2
1	736	2012-04-07	1500000.00	737	2012-04-09	1
1	737	2012-04-09	1500000.00	738	2012-04-11	1
1	738	2012-04-11	1500000.00	739	2012-04-13	1
1	739	2012-04-13	1500000.00	740	2012-04-16	4
1	740	2012-04-16	1500000.00	741	2012-04-18	1
1	741	2012-04-18	1500000.00	742	2012-04-20	2
1	742	2012-04-20	1500000.00	743	2012-04-23	4
1	743	2012-04-23	1500000.00	744	2012-04-25	1
1	744	2012-04-25	1500000.00	745	2012-04-27	2
1	745	2012-04-27	1500000.00	746	2012-04-30	3
1	746	2012-04-30	1500000.00	747	2012-05-02	3
1	747	2012-05-02	3300000.00	748	2012-05-04	0
1	748	2012-05-04	1500000.00	749	2012-05-07	4
1	749	2012-05-07	1500000.00	750	2012-05-09	1
1	750	2012-05-09	1500000.00	751	2012-05-11	8
1	751	2012-05-11	1500000.00	752	2012-05-14	7
1	752	2012-05-14	1500000.00	753	2012-05-16	7
1	753	2012-05-16	1500000.00	754	2012-05-18	6
1	754	2012-05-18	1500000.00	755	2012-05-21	3
1	755	2012-05-21	1500000.00	756	2012-05-23	2
1	756	2012-05-23	1500000.00	757	2012-05-25	3
1	757	2012-05-25	1500000.00	758	2012-05-28	5
1	758	2012-05-28	1500000.00	759	2012-05-30	3
1	759	2012-05-30	1500000.00	760	2012-06-01	2
1	760	2012-06-01	1500000.00	761	2012-06-04	9
1	761	2012-06-04	1500000.00	762	2012-06-06	1
1	762	2012-06-06	1300000.00	763	2012-06-08	2
1	763	2012-06-08	1500000.00	764	2012-06-11	3
1	764	2012-06-11	1500000.00	765	2012-06-13	16
1	765	2012-06-13	1500000.00	766	2012-06-15	8
1	766	2012-06-15	1500000.00	767	2012-06-18	5
1	767	2012-06-18	1500000.00	768	2012-06-20	8
1	768	2012-06-20	1500000.00	769	2012-06-22	4
1	769	2012-06-22	1500000.00	770	2012-06-25	5
1	770	2012-06-25	1500000.00	771	2012-06-27	4
1	771	2012-06-27	1500000.00	772	2012-06-29	1
1	772	2012-06-29	1500000.00	773	2012-07-02	1
1	773	2012-07-02	1500000.00	774	2012-07-04	12
1	774	2012-07-04	1500000.00	775	2012-07-06	1
1	775	2012-07-06	1500000.00	776	2012-07-09	20
1	776	2012-07-09	1500000.00	777	2012-07-11	5
1	777	2012-07-11	1500000.00	778	2012-07-13	1
1	778	2012-07-13	1500000.00	779	2012-07-16	8
1	779	2012-07-16	1500000.00	780	2012-07-18	3
1	780	2012-07-18	1500000.00	781	2012-07-20	2
1	781	2012-07-20	3700000.00	782	2012-07-23	0
1	782	2012-07-23	1500000.00	783	2012-07-25	30
1	783	2012-07-25	1500000.00	784	2012-07-27	8
1	784	2012-07-27	1500000.00	785	2012-07-30	4
1	785	2012-07-30	1500000.00	786	2012-08-01	5
1	786	2012-08-01	1500000.00	787	2012-08-03	5
1	787	2012-08-03	1500000.00	788	2012-08-06	6
1	788	2012-08-06	1500000.00	789	2012-08-08	5
1	789	2012-08-08	1500000.00	790	2012-08-10	7
1	790	2012-08-10	1500000.00	791	2012-08-13	3
1	791	2012-08-13	1500000.00	792	2012-08-15	3
1	792	2012-08-15	1500000.00	793	2012-08-17	7
1	793	2012-08-17	1500000.00	794	2012-08-20	22
1	794	2012-08-20	1500000.00	795	2012-08-22	1
1	795	2012-08-22	1500000.00	796	2012-08-24	3
1	796	2012-08-24	1500000.00	797	2012-08-27	7
1	797	2012-08-27	1500000.00	798	2012-08-29	2
1	798	2012-08-29	1500000.00	799	2012-08-31	94
1	799	2012-08-31	40000000.00	800	2012-09-06	6
1	800	2012-09-06	1500000.00	801	2012-09-10	14
1	801	2012-09-10	1500000.00	802	2012-09-12	4
1	802	2012-09-12	1500000.00	803	2012-09-14	5
1	803	2012-09-14	1500000.00	804	2012-09-17	2
1	804	2012-09-17	1500000.00	805	2012-09-19	2
1	805	2012-09-19	1500000.00	806	2012-09-21	21
1	806	2012-09-21	1500000.00	807	2012-09-24	4
1	807	2012-09-24	1500000.00	808	2012-09-26	3
1	808	2012-09-26	1500000.00	809	2012-09-28	2
1	809	2012-09-28	1500000.00	810	2012-10-01	4
1	810	2012-10-01	1500000.00	811	2012-10-03	3
1	811	2012-10-03	1500000.00	812	2012-10-05	6
1	812	2012-10-05	3500000.00	813	2012-10-08	0
1	813	2012-10-08	1500000.00	814	2012-10-10	6
1	814	2012-10-10	1500000.00	815	2012-10-13	4
1	815	2012-10-13	1500000.00	816	2012-10-15	4
1	816	2012-10-15	1500000.00	817	2012-10-17	7
1	817	2012-10-17	1500000.00	818	2012-10-19	2
1	818	2012-10-19	1500000.00	819	2012-10-22	1
1	819	2012-10-22	1500000.00	820	2012-10-24	36
1	820	2012-10-24	1500000.00	821	2012-10-26	2
1	821	2012-10-26	1500000.00	822	2012-10-29	2
1	822	2012-10-29	1500000.00	823	2012-10-31	1
1	823	2012-10-31	1500000.00	824	2012-11-03	4
1	824	2012-11-03	1500000.00	825	2012-11-05	3
1	825	2012-11-05	3200000.00	826	2012-11-07	0
1	826	2012-11-07	1500000.00	827	2012-11-09	2
1	827	2012-11-09	1500000.00	828	2012-11-12	4
1	828	2012-11-12	1500000.00	829	2012-11-14	1
1	829	2012-11-14	1300000.00	830	2012-11-16	10
1	830	2012-11-16	1500000.00	831	2012-11-19	2
1	831	2012-11-19	1500000.00	832	2012-11-21	5
1	832	2012-11-21	1500000.00	833	2012-11-23	5
1	833	2012-11-23	1500000.00	834	2012-11-26	3
1	834	2012-11-26	1500000.00	835	2012-11-28	5
1	835	2012-11-28	1500000.00	836	2012-11-30	3
1	836	2012-11-30	1500000.00	837	2012-12-03	4
1	837	2012-12-03	1500000.00	838	2012-12-05	7
1	838	2012-12-05	1500000.00	839	2012-12-07	21
1	839	2012-12-07	1500000.00	840	2012-12-10	2
1	840	2012-12-10	1500000.00	841	2012-12-12	4
1	841	2012-12-12	1500000.00	842	2012-12-14	8
1	842	2012-12-14	1500000.00	843	2012-12-17	5
1	843	2012-12-17	1500000.00	844	2012-12-19	8
1	844	2012-12-19	1500000.00	845	2012-12-21	3
1	845	2012-12-21	1500000.00	846	2012-12-24	3
1	846	2012-12-24	1500000.00	847	2012-12-26	1
1	847	2012-12-26	1500000.00	848	2012-12-28	3
1	848	2012-12-28	1500000.00	849	2012-12-31	1
1	849	2012-12-31	1500000.00	850	2013-01-02	2
1	850	2013-01-02	1500000.00	851	2013-01-04	2
1	851	2013-01-04	1500000.00	852	2013-01-07	3
1	852	2013-01-07	1500000.00	853	2013-01-09	4
1	853	2013-01-09	1500000.00	854	2013-01-11	4
1	854	2013-01-11	1500000.00	855	2013-01-14	2
1	855	2013-01-14	1500000.00	856	2013-01-16	3
1	856	2013-01-16	1500000.00	857	2013-01-18	5
1	857	2013-01-18	1500000.00	858	2013-01-21	3
1	858	2013-01-21	1500000.00	859	2013-01-23	5
1	859	2013-01-23	1500000.00	860	2013-01-25	2
1	860	2013-01-25	1500000.00	861	2013-01-28	2
1	861	2013-01-28	1500000.00	862	2013-01-30	3
1	862	2013-01-30	1500000.00	863	2013-02-01	7
1	863	2013-02-01	1500000.00	864	2013-02-04	4
1	864	2013-02-04	1500000.00	865	2013-02-06	3
1	865	2013-02-06	3500000.00	866	2013-02-08	0
1	866	2013-02-08	1500000.00	867	2013-02-13	6
1	867	2013-02-13	1500000.00	868	2013-02-15	1
1	868	2013-02-15	1500000.00	869	2013-02-18	9
1	869	2013-02-18	1500000.00	870	2013-02-20	6
1	870	2013-02-20	1500000.00	871	2013-02-22	5
1	871	2013-02-22	1500000.00	872	2013-02-25	10
1	872	2013-02-25	1500000.00	873	2013-02-27	12
1	873	2013-02-27	3500000.00	874	2013-03-01	0
1	874	2013-03-01	1500000.00	875	2013-03-04	5
1	875	2013-03-04	1500000.00	876	2013-03-06	6
1	876	2013-03-06	1500000.00	877	2013-03-08	8
1	877	2013-03-08	1500000.00	878	2013-03-11	6
1	878	2013-03-11	1500000.00	879	2013-03-13	6
1	879	2013-03-13	1500000.00	880	2013-03-15	5
1	880	2013-03-15	1500000.00	881	2013-03-18	2
1	881	2013-03-18	1500000.00	882	2013-03-20	4
1	882	2013-03-20	1500000.00	883	2013-03-22	4
1	883	2013-03-22	1500000.00	884	2013-03-25	2
1	884	2013-03-25	1500000.00	885	2013-03-27	1
1	885	2013-03-27	1400000.00	886	2013-03-30	2
1	886	2013-03-30	1500000.00	887	2013-04-01	1
1	887	2013-04-01	3500000.00	888	2013-04-03	0
1	888	2013-04-03	1500000.00	889	2013-04-05	2
1	889	2013-04-05	1500000.00	890	2013-04-08	3
1	890	2013-04-08	1500000.00	891	2013-04-10	1
1	891	2013-04-10	1500000.00	892	2013-04-12	6
1	892	2013-04-12	1500000.00	893	2013-04-15	2
1	893	2013-04-15	3500000.00	894	2013-04-17	0
1	894	2013-04-17	1800000.00	895	2013-04-19	4
1	895	2013-04-19	1800000.00	896	2013-04-22	1
1	896	2013-04-22	3500000.00	897	2013-04-24	0
1	897	2013-04-24	1500000.00	898	2013-04-26	1
1	898	2013-04-26	3500000.00	899	2013-04-29	0
1	899	2013-04-29	1500000.00	900	2013-05-03	8
1	900	2013-05-03	1600000.00	901	2013-05-06	4
1	901	2013-05-06	1500000.00	902	2013-05-08	1
1	902	2013-05-08	1500000.00	903	2013-05-10	1
1	903	2013-05-10	1500000.00	904	2013-05-13	29
1	904	2013-05-13	1500000.00	905	2013-05-15	3
1	905	2013-05-15	1500000.00	906	2013-05-17	3
1	906	2013-05-17	1500000.00	907	2013-05-20	1
1	907	2013-05-20	1500000.00	908	2013-05-22	2
1	908	2013-05-22	1500000.00	909	2013-05-24	7
1	909	2013-05-24	1700000.00	910	2013-05-27	4
1	910	2013-05-27	1700000.00	911	2013-05-29	5
1	911	2013-05-29	1500000.00	912	2013-05-31	3
1	912	2013-05-31	1500000.00	913	2013-06-03	1
1	913	2013-06-03	1500000.00	914	2013-06-05	3
1	914	2013-06-05	1500000.00	915	2013-06-07	2
1	915	2013-06-07	1500000.00	916	2013-06-10	9
1	916	2013-06-10	1500000.00	917	2013-06-12	1
1	917	2013-06-12	1500000.00	918	2013-06-14	1
1	918	2013-06-14	1500000.00	919	2013-06-17	4
1	919	2013-06-17	1500000.00	920	2013-06-19	9
1	920	2013-06-19	1500000.00	921	2013-06-21	7
1	921	2013-06-21	1500000.00	922	2013-06-24	4
1	922	2013-06-24	1500000.00	923	2013-06-26	1
1	923	2013-06-26	1500000.00	924	2013-06-28	4
1	924	2013-06-28	1500000.00	925	2013-07-01	1
1	925	2013-07-01	1500000.00	926	2013-07-03	6
1	926	2013-07-03	1500000.00	927	2013-07-05	2
1	927	2013-07-05	1500000.00	928	2013-07-08	4
1	928	2013-07-08	1500000.00	929	2013-07-10	3
1	929	2013-07-10	1500000.00	930	2013-07-12	2
1	930	2013-07-12	1500000.00	931	2013-07-15	4
1	931	2013-07-15	1500000.00	932	2013-07-17	19
1	932	2013-07-17	1500000.00	933	2013-07-19	3
1	933	2013-07-19	1500000.00	934	2013-07-22	4
1	934	2013-07-22	1500000.00	935	2013-07-24	6
1	935	2013-07-24	1500000.00	936	2013-07-26	7
1	936	2013-07-26	1500000.00	937	2013-07-29	5
1	937	2013-07-29	1500000.00	938	2013-07-31	2
1	938	2013-07-31	1500000.00	939	2013-08-02	2
1	939	2013-08-02	1500000.00	940	2013-08-05	5
1	940	2013-08-05	1500000.00	941	2013-08-07	8
1	941	2013-08-07	1500000.00	942	2013-08-09	2
1	942	2013-08-09	1500000.00	943	2013-08-12	7
1	943	2013-08-12	1500000.00	944	2013-08-14	5
1	944	2013-08-14	1500000.00	945	2013-08-16	3
1	945	2013-08-16	1500000.00	946	2013-08-19	2
1	946	2013-08-19	1500000.00	947	2013-08-21	3
1	947	2013-08-21	1500000.00	948	2013-08-23	8
1	948	2013-08-23	4000000.00	949	2013-08-26	0
1	949	2013-08-26	1500000.00	950	2013-08-28	3
1	950	2013-08-28	1500000.00	951	2013-08-30	5
1	951	2013-08-30	70000000.00	952	2013-09-06	1
1	952	2013-09-07	1500000.00	953	2013-09-09	66
1	953	2013-09-09	1500000.00	954	2013-09-11	3
1	954	2013-09-11	1500000.00	955	2013-09-13	4
1	955	2013-09-13	1500000.00	956	2013-09-16	8
1	956	2013-09-16	1500000.00	957	2013-09-18	7
1	957	2013-09-18	1500000.00	958	2013-09-20	4
1	958	2013-09-20	1500000.00	959	2013-09-23	6
1	959	2013-09-23	1500000.00	960	2013-09-25	5
1	960	2013-09-25	1500000.00	961	2013-09-27	5
1	961	2013-09-27	1500000.00	962	2013-09-30	4
1	962	2013-09-30	1500000.00	963	2013-10-02	4
1	963	2013-10-02	1500000.00	964	2013-10-04	2
1	964	2013-10-04	1500000.00	965	2013-10-07	1
1	965	2013-10-07	1500000.00	966	2013-10-09	2
1	966	2013-10-09	1500000.00	967	2013-10-11	5
1	967	2013-10-11	1700000.00	968	2013-10-14	1
1	968	2013-10-14	1500000.00	969	2013-10-16	3
1	969	2013-10-16	1700000.00	970	2013-10-18	1
1	970	2013-10-18	1700000.00	971	2013-10-21	4
1	971	2013-10-21	1600000.00	972	2013-10-23	2
1	972	2013-10-23	1500000.00	973	2013-10-25	4
1	973	2013-10-25	1500000.00	974	2013-10-28	3
1	974	2013-10-28	1500000.00	975	2013-10-30	5
1	975	2013-10-30	1500000.00	976	2013-11-01	2
1	976	2013-11-01	1500000.00	977	2013-11-04	7
1	977	2013-11-04	1500000.00	978	2013-11-06	2
1	978	2013-11-06	1500000.00	979	2013-11-08	2
1	979	2013-11-08	1500000.00	980	2013-11-11	7
1	980	2013-11-11	1500000.00	981	2013-11-13	2
1	981	2013-11-13	1500000.00	982	2013-11-16	1
1	982	2013-11-16	1500000.00	983	2013-11-18	5
1	983	2013-11-18	1500000.00	984	2013-11-20	3
1	984	2013-11-20	1500000.00	985	2013-11-22	3
1	985	2013-11-22	1500000.00	986	2013-11-25	9
1	986	2013-11-25	1500000.00	987	2013-11-27	1
1	987	2013-11-27	1500000.00	988	2013-11-29	8
1	988	2013-11-29	1500000.00	989	2013-12-02	7
1	989	2013-12-02	1500000.00	990	2013-12-04	10
1	990	2013-12-04	1500000.00	991	2013-12-06	3
1	991	2013-12-06	1500000.00	992	2013-12-09	2
1	992	2013-12-09	1500000.00	993	2013-12-11	3
1	993	2013-12-11	1500000.00	994	2013-12-13	13
1	994	2013-12-13	1500000.00	995	2013-12-16	4
1	995	2013-12-16	1500000.00	996	2013-12-18	8
1	996	2013-12-18	1500000.00	997	2013-12-20	6
1	997	2013-12-20	1500000.00	998	2013-12-23	1
1	998	2013-12-23	1500000.00	999	2013-12-27	4
1	999	2013-12-27	1500000.00	1000	2013-12-30	13
1	1000	2013-12-30	1500000.00	1001	2014-01-03	5
1	1001	2014-01-03	1500000.00	1002	2014-01-06	2
1	1002	2014-01-06	1500000.00	1003	2014-01-08	3
1	1003	2014-01-09	1500000.00	1004	2014-01-10	20
1	1004	2014-01-10	1500000.00	1005	2014-01-13	2
1	1005	2014-01-13	1500000.00	1006	2014-01-15	6
1	1006	2014-01-15	4300000.00	1007	2014-01-17	0
1	1007	2014-01-17	1500000.00	1008	2014-01-20	3
1	1008	2014-01-20	1500000.00	1009	2014-01-22	3
1	1009	2014-01-22	1500000.00	1010	2014-01-24	5
1	1010	2014-01-24	1500000.00	1011	2014-01-27	1
1	1011	2014-01-27	1500000.00	1012	2014-01-29	11
1	1012	2014-01-29	1500000.00	1013	2014-01-31	2
1	1013	2014-01-31	1500000.00	1014	2014-02-03	2
1	1014	2014-02-03	1500000.00	1015	2014-02-05	7
1	1015	2014-02-05	1500000.00	1016	2014-02-07	5
1	1016	2014-02-07	1500000.00	1017	2014-02-10	3
1	1017	2014-02-10	1500000.00	1018	2014-02-12	4
1	1018	2014-02-12	1500000.00	1019	2014-02-14	10
1	1019	2014-02-14	1500000.00	1020	2014-02-17	4
1	1020	2014-02-17	1500000.00	1021	2014-02-19	5
1	1021	2014-02-19	1500000.00	1022	2014-02-21	2
1	1022	2014-02-21	1500000.00	1023	2014-02-24	1
1	1023	2014-02-24	1500000.00	1024	2014-02-26	5
1	1024	2014-02-26	1500000.00	1025	2014-02-28	1
1	1025	2014-02-28	1500000.00	1026	2014-03-05	4
1	1026	2014-03-05	1500000.00	1027	2014-03-07	3
1	1027	2014-03-07	1500000.00	1028	2014-03-10	18
1	1028	2014-03-10	1500000.00	1029	2014-03-12	1
1	1029	2014-03-12	1500000.00	1030	2014-03-14	4
1	1030	2014-03-14	1500000.00	1031	2014-03-17	3
1	1031	2014-03-17	1500000.00	1032	2014-03-19	5
1	1032	2014-03-19	1500000.00	1033	2014-03-21	1
1	1033	2014-03-21	1500000.00	1034	2014-03-24	17
1	1034	2014-03-24	1500000.00	1035	2014-03-26	13
1	1035	2014-03-26	1500000.00	1036	2014-03-28	2
1	1036	2014-03-28	1500000.00	1037	2014-03-31	5
1	1037	2014-03-31	1500000.00	1038	2014-04-02	5
1	1038	2014-04-02	1500000.00	1039	2014-04-04	4
1	1039	2014-04-04	1500000.00	1040	2014-04-07	8
1	1040	2014-04-07	1500000.00	1041	2014-04-09	3
1	1041	2014-04-09	1500000.00	1042	2014-04-11	23
1	1042	2014-04-11	1500000.00	1043	2014-04-14	2
1	1043	2014-04-14	1500000.00	1044	2014-04-16	1
1	1044	2014-04-16	1500000.00	1045	2014-04-19	5
1	1045	2014-04-19	1500000.00	1046	2014-04-23	4
1	1046	2014-04-23	1500000.00	1047	2014-04-25	2
1	1047	2014-04-25	1500000.00	1048	2014-04-28	5
1	1048	2014-04-28	1500000.00	1049	2014-04-30	3
1	1049	2014-04-30	1000000.00	1050	2014-05-02	2
1	1050	2014-05-02	1500000.00	1051	2014-05-05	3
1	1051	2014-05-05	1500000.00	1052	2014-05-07	47
1	1052	2014-05-07	1500000.00	1053	2014-05-09	1
1	1053	2014-05-09	1500000.00	1054	2014-05-12	2
1	1054	2014-05-12	4500000.00	1055	2014-05-14	0
1	1055	2014-05-14	1500000.00	1056	2014-05-16	7
1	1056	2014-05-16	1500000.00	1057	2014-05-19	1
1	1057	2014-05-19	1500000.00	1058	2014-05-21	2
1	1058	2014-05-21	3500000.00	1059	2014-05-23	0
1	1059	2014-05-23	1700000.00	1060	2014-05-26	6
1	1060	2014-05-26	1700000.00	1061	2014-05-28	8
1	1061	2014-05-28	4000000.00	1062	2014-05-30	0
1	1062	2014-05-30	1700000.00	1063	2014-06-02	6
1	1063	2014-06-02	1700000.00	1064	2014-06-04	2
1	1064	2014-06-04	1700000.00	1065	2014-06-06	3
1	1065	2014-06-06	1700000.00	1066	2014-06-09	6
1	1066	2014-06-09	1700000.00	1067	2014-06-11	1
1	1067	2014-06-11	1700000.00	1068	2014-06-13	3
1	1068	2014-06-13	1700000.00	1069	2014-06-16	1
1	1069	2014-06-16	1700000.00	1070	2014-06-18	4
1	1070	2014-06-18	1500000.00	1071	2014-06-20	1
1	1071	2014-06-20	1700000.00	1072	2014-06-23	2
1	1072	2014-06-23	1700000.00	1073	2014-06-25	5
1	1073	2014-06-25	4000000.00	1074	2014-06-27	0
1	1074	2014-06-27	1700000.00	1075	2014-06-30	2
1	1075	2014-06-30	1700000.00	1076	2014-07-02	1
1	1076	2014-07-02	1700000.00	1077	2014-07-04	3
1	1077	2014-07-04	1700000.00	1078	2014-07-07	3
1	1078	2014-07-07	1700000.00	1079	2014-07-09	2
1	1079	2014-07-09	1700000.00	1080	2014-07-11	4
1	1080	2014-07-11	1700000.00	1081	2014-07-14	2
1	1081	2014-07-14	1700000.00	1082	2014-07-16	2
1	1082	2014-07-16	1700000.00	1083	2014-07-18	2
1	1083	2014-07-18	1700000.00	1084	2014-07-21	1
1	1084	2014-07-21	1700000.00	1085	2014-07-23	4
1	1085	2014-07-23	1700000.00	1086	2014-07-25	4
1	1086	2014-07-25	1700000.00	1087	2014-07-28	6
1	1087	2014-07-28	1700000.00	1088	2014-07-30	3
1	1088	2014-07-30	1700000.00	1089	2014-08-01	3
1	1089	2014-08-01	1700000.00	1090	2014-08-04	6
1	1090	2014-08-04	1700000.00	1091	2014-08-06	6
1	1091	2014-08-06	1700000.00	1092	2014-08-08	1
1	1092	2014-08-08	4500000.00	1093	2014-08-11	0
1	1093	2014-08-11	1700000.00	1094	2014-08-13	6
1	1094	2014-08-13	1700000.00	1095	2014-08-15	1
1	1095	2014-08-15	1700000.00	1096	2014-08-18	5
1	1096	2014-08-18	1700000.00	1097	2014-08-20	1
1	1097	2014-08-20	1700000.00	1098	2014-08-22	2
1	1098	2014-08-22	1700000.00	1099	2014-08-25	6
1	1099	2014-08-25	4500000.00	1100	2014-08-27	0
1	1100	2014-08-27	1700000.00	1101	2014-08-29	6
1	1101	2014-08-29	80000000.00	1102	2014-09-06	4
1	1102	2014-09-07	1500000.00	1103	2014-09-08	43
1	1103	2014-09-08	1700000.00	1104	2014-09-10	21
1	1104	2014-09-10	1700000.00	1105	2014-09-12	6
1	1105	2014-09-12	1800000.00	1106	2014-09-15	15
1	1106	2014-09-15	1700000.00	1107	2014-09-17	4
1	1107	2014-09-17	1700000.00	1108	2014-09-19	7
1	1108	2014-09-19	1700000.00	1109	2014-09-22	4
1	1109	2014-09-22	1700000.00	1110	2014-09-24	2
1	1110	2014-09-24	5000000.00	1111	2014-09-26	0
1	1111	2014-09-26	1700000.00	1112	2014-09-29	4
1	1112	2014-09-29	1700000.00	1113	2014-10-01	5
1	1113	2014-10-01	1700000.00	1114	2014-10-03	4
1	1114	2014-10-03	1700000.00	1115	2014-10-06	4
1	1115	2014-10-06	1700000.00	1116	2014-10-08	3
1	1116	2014-10-08	1700000.00	1117	2014-10-10	4
1	1117	2014-10-10	1700000.00	1118	2014-10-13	3
1	1118	2014-10-13	1700000.00	1119	2014-10-15	7
1	1119	2014-10-15	1700000.00	1120	2014-10-17	6
1	1120	2014-10-17	1700000.00	1121	2014-10-20	2
1	1121	2014-10-20	1700000.00	1122	2014-10-22	3
1	1122	2014-10-22	1700000.00	1123	2014-10-24	4
1	1123	2014-10-24	1700000.00	1124	2014-10-27	7
1	1124	2014-10-27	1700000.00	1125	2014-10-29	3
1	1125	2014-10-29	1700000.00	1126	2014-10-31	3
1	1126	2014-10-31	1700000.00	1127	2014-11-03	2
1	1127	2014-11-03	1700000.00	1128	2014-11-05	1
1	1128	2014-11-05	1700000.00	1129	2014-11-07	1
1	1129	2014-11-07	1700000.00	1130	2014-11-10	5
1	1130	2014-11-10	1700000.00	1131	2014-11-12	3
1	1131	2014-11-12	1700000.00	1132	2014-11-14	2
1	1132	2014-11-14	1700000.00	1133	2014-11-17	2
1	1133	2014-11-17	1700000.00	1134	2014-11-19	2
1	1134	2014-11-19	1700000.00	1135	2014-11-21	5
1	1135	2014-11-21	1700000.00	1136	2014-11-24	4
1	1136	2014-11-24	1700000.00	1137	2014-11-26	4
1	1137	2014-11-26	1700000.00	1138	2014-11-28	2
1	1138	2014-11-28	1700000.00	1139	2014-12-01	4
1	1139	2014-12-01	1700000.00	1140	2014-12-03	1
1	1140	2014-12-03	5000000.00	1141	2014-12-05	0
1	1141	2014-12-05	1700000.00	1142	2014-12-08	4
1	1142	2014-12-08	1700000.00	1143	2014-12-10	2
1	1143	2014-12-10	1700000.00	1144	2014-12-12	4
1	1144	2014-12-12	1700000.00	1145	2014-12-15	6
1	1145	2014-12-15	1700000.00	1146	2014-12-17	6
1	1146	2014-12-17	1700000.00	1147	2014-12-19	4
1	1147	2014-12-19	1700000.00	1148	2014-12-22	1
1	1148	2014-12-22	1700000.00	1149	2014-12-24	2
1	1149	2014-12-24	1500000.00	1150	2014-12-26	2
1	1150	2014-12-26	1700000.00	1151	2014-12-29	2
1	1151	2014-12-29	1500000.00	1152	2014-12-31	4
1	1152	2014-12-31	1500000.00	1153	2015-01-02	2
1	1153	2015-01-02	1500000.00	1154	2015-01-05	3
1	1154	2015-01-05	3500000.00	1155	2015-01-07	0
1	1155	2015-01-07	1700000.00	1156	2015-01-09	8
1	1156	2015-01-09	3500000.00	1157	2015-01-12	0
1	1157	2015-01-12	1700000.00	1158	2015-01-14	6
1	1158	2015-01-14	1700000.00	1159	2015-01-16	9
1	1159	2015-01-16	1700000.00	1160	2015-01-19	3
1	1160	2015-01-19	1700000.00	1161	2015-01-21	3
1	1161	2015-01-21	1700000.00	1162	2015-01-23	5
1	1162	2015-01-23	1700000.00	1163	2015-01-26	11
1	1163	2015-01-26	1700000.00	1164	2015-01-28	1
1	1164	2015-01-28	1700000.00	1165	2015-01-30	7
1	1165	2015-01-30	1700000.00	1166	2015-02-02	2
1	1166	2015-02-02	1700000.00	1167	2015-02-04	3
1	1167	2015-02-04	1700000.00	1168	2015-02-06	4
1	1168	2015-02-06	1700000.00	1169	2015-02-09	5
1	1169	2015-02-09	1700000.00	1170	2015-02-11	4
1	1170	2015-02-11	1700000.00	1171	2015-02-13	3
1	1171	2015-02-13	1700000.00	1172	2015-02-18	1
1	1172	2015-02-18	1700000.00	1173	2015-02-20	1
1	1173	2015-02-20	1700000.00	1174	2015-02-23	1
1	1174	2015-02-23	1700000.00	1175	2015-02-25	7
1	1175	2015-02-25	1700000.00	1176	2015-02-27	1
1	1176	2015-02-27	1700000.00	1177	2015-03-02	3
1	1177	2015-03-02	1700000.00	1178	2015-03-04	3
1	1178	2015-03-04	1700000.00	1179	2015-03-06	3
1	1179	2015-03-06	1700000.00	1180	2015-03-09	3
1	1180	2015-03-09	5000000.00	1181	2015-03-11	0
1	1181	2015-03-11	1700000.00	1182	2015-03-13	3
1	1182	2015-03-13	1700000.00	1183	2015-03-16	3
1	1183	2015-03-16	1700000.00	1184	2015-03-18	3
1	1184	2015-03-18	1700000.00	1185	2015-03-20	1
1	1185	2015-03-20	1700000.00	1186	2015-03-23	3
1	1186	2015-03-23	1700000.00	1187	2015-03-25	4
1	1187	2015-03-25	1700000.00	1188	2015-03-27	9
1	1188	2015-03-27	1700000.00	1189	2015-03-30	4
1	1189	2015-03-30	1700000.00	1190	2015-04-01	6
1	1190	2015-04-01	1700000.00	1191	2015-04-04	1
1	1191	2015-04-04	1700000.00	1192	2015-04-06	1
1	1192	2015-04-06	1700000.00	1193	2015-04-08	1
1	1193	2015-04-08	1700000.00	1194	2015-04-10	1
1	1194	2015-04-10	1700000.00	1195	2015-04-13	1
1	1195	2015-04-13	1700000.00	1196	2015-04-15	2
1	1196	2015-04-15	1700000.00	1197	2015-04-17	3
1	1197	2015-04-17	1700000.00	1198	2015-04-20	3
1	1198	2015-04-20	1700000.00	1199	2015-04-22	1
1	1199	2015-04-22	1700000.00	1200	2015-04-24	2
1	1200	2015-04-24	1700000.00	1201	2015-04-27	2
1	1201	2015-04-27	1700000.00	1202	2015-04-29	2
1	1202	2015-04-29	1700000.00	1203	2015-05-02	5
1	1203	2015-05-02	1500000.00	1204	2015-05-04	4
1	1204	2015-05-04	1700000.00	1205	2015-05-06	8
1	1205	2015-05-06	1700000.00	1206	2015-05-08	2
1	1206	2015-05-08	1700000.00	1207	2015-05-11	7
1	1207	2015-05-11	1700000.00	1208	2015-05-13	2
1	1208	2015-05-13	1700000.00	1209	2015-05-15	1
1	1209	2015-05-15	1700000.00	1210	2015-05-18	3
1	1210	2015-05-18	1700000.00	1211	2015-05-20	13
1	1211	2015-05-20	1700000.00	1212	2015-05-22	2
1	1212	2015-05-22	1700000.00	1213	2015-05-25	4
1	1213	2015-05-25	1700000.00	1214	2015-05-27	6
1	1214	2015-05-27	1700000.00	1215	2015-05-29	2
1	1215	2015-05-29	1700000.00	1216	2015-06-01	2
1	1216	2015-06-01	1700000.00	1217	2015-06-03	1
1	1217	2015-06-03	1700000.00	1218	2015-06-05	1
1	1218	2015-06-05	1700000.00	1219	2015-06-08	1
1	1219	2015-06-08	4500000.00	1220	2015-06-10	0
1	1220	2015-06-10	1700000.00	1221	2015-06-12	4
1	1221	2015-06-12	1700000.00	1222	2015-06-15	2
1	1222	2015-06-15	1700000.00	1223	2015-06-17	5
1	1223	2015-06-17	1700000.00	1224	2015-06-19	1
1	1224	2015-06-19	1700000.00	1225	2015-06-22	4
1	1225	2015-06-22	1700000.00	1226	2015-06-24	2
1	1226	2015-06-24	1700000.00	1227	2015-06-26	3
1	1227	2015-06-26	1700000.00	1228	2015-06-29	2
1	1228	2015-06-29	1700000.00	1229	2015-07-01	2
1	1229	2015-07-01	1700000.00	1230	2015-07-03	4
1	1230	2015-07-03	1700000.00	1231	2015-07-06	1
1	1231	2015-07-06	1700000.00	1232	2015-07-08	2
1	1232	2015-07-08	1700000.00	1233	2015-07-10	1
1	1233	2015-07-10	1700000.00	1234	2015-07-13	3
1	1234	2015-07-13	1700000.00	1235	2015-07-15	1
1	1235	2015-07-15	1700000.00	1236	2015-07-17	1
1	1236	2015-07-17	1700000.00	1237	2015-07-20	9
1	1237	2015-07-20	1700000.00	1238	2015-07-22	1
1	1238	2015-07-22	1700000.00	1239	2015-07-24	2
1	1239	2015-07-24	1700000.00	1240	2015-07-27	2
1	1240	2015-07-27	1700000.00	1241	2015-07-29	3
1	1241	2015-07-29	1700000.00	1242	2015-07-31	1
1	1242	2015-07-31	4500000.00	1243	2015-08-03	0
1	1243	2015-08-03	1700000.00	1244	2015-08-05	2
1	1244	2015-08-05	1700000.00	1245	2015-08-07	37
1	1245	2015-08-07	4500000.00	1246	2015-08-10	0
1	1246	2015-08-10	1700000.00	1247	2015-08-12	2
1	1247	2015-08-12	1700000.00	1248	2015-08-14	1
1	1248	2015-08-14	1700000.00	1249	2015-08-17	1
1	1249	2015-08-17	1700000.00	1250	2015-08-19	2
1	1250	2015-08-19	1700000.00	1251	2015-08-21	3
1	1251	2015-08-21	1700000.00	1252	2015-08-24	1
1	1252	2015-08-24	1700000.00	1253	2015-08-26	1
1	1253	2015-08-26	4500000.00	1254	2015-08-28	0
1	1254	2015-08-28	85000000.00	1255	2015-09-08	3
1	1255	2015-09-08	2000000.00	1256	2015-09-09	51
1	1256	2015-09-09	4000000.00	1257	2015-09-11	0
1	1257	2015-09-11	1700000.00	1258	2015-09-14	4
1	1258	2015-09-14	1700000.00	1259	2015-09-16	3
1	1259	2015-09-16	1700000.00	1260	2015-09-18	2
1	1260	2015-09-18	1700000.00	1261	2015-09-21	3
1	1261	2015-09-21	1700000.00	1262	2015-09-23	1
1	1262	2015-09-23	1700000.00	1263	2015-09-25	2
1	1263	2015-09-25	1700000.00	1264	2015-09-28	5
1	1264	2015-09-28	1700000.00	1265	2015-09-30	3
1	1265	2015-09-30	1700000.00	1266	2015-10-02	1
1	1266	2015-10-02	1700000.00	1267	2015-10-05	2
1	1267	2015-10-05	1700000.00	1268	2015-10-07	2
1	1268	2015-10-07	1700000.00	1269	2015-10-09	7
1	1269	2015-10-09	1700000.00	1270	2015-10-13	1
1	1270	2015-10-13	1000000.00	1271	2015-10-14	1
1	1271	2015-10-14	1700000.00	1272	2015-10-16	4
1	1272	2015-10-16	1700000.00	1273	2015-10-19	2
1	1273	2015-10-19	1700000.00	1274	2015-10-21	2
1	1274	2015-10-21	4500000.00	1275	2015-10-23	0
1	1275	2015-10-23	1700000.00	1276	2015-10-26	3
1	1276	2015-10-26	1700000.00	1277	2015-10-28	6
1	1277	2015-10-28	1700000.00	1278	2015-10-30	3
1	1278	2015-10-30	1700000.00	1279	2015-11-03	2
1	1279	2015-11-03	1700000.00	1280	2015-11-04	2
1	1280	2015-11-04	1700000.00	1281	2015-11-06	3
1	1281	2015-11-06	1700000.00	1282	2015-11-09	3
1	1282	2015-11-09	1700000.00	1283	2015-11-11	1
1	1283	2015-11-11	1700000.00	1284	2015-11-13	1
1	1284	2015-11-13	1700000.00	1285	2015-11-16	8
1	1285	2015-11-16	1700000.00	1286	2015-11-18	2
1	1286	2015-11-18	1700000.00	1287	2015-11-20	3
1	1287	2015-11-20	1700000.00	1288	2015-11-23	1
1	1288	2015-11-23	1700000.00	1289	2015-11-25	1
1	1289	2015-11-25	1700000.00	1290	2015-11-27	10
1	1290	2015-11-27	4500000.00	1291	2015-11-30	0
1	1291	2015-11-30	7500000.00	1292	2015-12-02	0
1	1292	2015-12-02	1700000.00	1293	2015-12-04	5
1	1293	2015-12-04	1700000.00	1294	2015-12-07	5
1	1294	2015-12-07	1700000.00	1295	2015-12-09	2
1	1295	2015-12-09	1700000.00	1296	2015-12-11	2
1	1296	2015-12-11	1700000.00	1297	2015-12-14	1
1	1297	2015-12-14	1700000.00	1298	2015-12-16	4
1	1298	2015-12-16	1700000.00	1299	2015-12-18	2
1	1299	2015-12-18	1700000.00	1300	2015-12-21	2
1	1300	2015-12-21	1700000.00	1301	2015-12-23	2
1	1301	2015-12-23	1700000.00	1302	2015-12-26	1
1	1302	2015-12-26	1500000.00	1303	2015-12-28	2
1	1303	2015-12-28	1700000.00	1304	2015-12-30	3
1	1304	2015-12-30	1700000.00	1305	2016-01-02	3
1	1305	2016-01-02	2000000.00	1306	2016-01-04	0
1	1306	2016-01-04	4000000.00	1307	2016-01-06	0
1	1307	2016-01-06	1700000.00	1308	2016-01-08	1
1	1308	2016-01-08	1700000.00	1309	2016-01-11	1
1	1309	2016-01-11	1700000.00	1310	2016-01-13	4
1	1310	2016-01-13	1500000.00	1311	2016-01-15	2
1	1311	2016-01-15	1700000.00	1312	2016-01-18	9
1	1312	2016-01-18	1500000.00	1313	2016-01-20	5
1	1313	2016-01-20	1700000.00	1314	2016-01-22	4
1	1314	2016-01-22	1700000.00	1315	2016-01-25	2
1	1315	2016-01-25	1700000.00	1316	2016-01-27	5
1	1316	2016-01-27	1700000.00	1317	2016-01-29	2
1	1317	2016-01-29	1500000.00	1318	2016-02-01	3
1	1318	2016-02-01	1700000.00	1319	2016-02-03	4
1	1319	2016-02-03	1700000.00	1320	2016-02-05	12
1	1320	2016-02-05	1700000.00	1321	2016-02-10	3
1	1321	2016-02-10	1700000.00	1322	2016-02-12	3
1	1322	2016-02-12	1700000.00	1323	2016-02-15	3
1	1323	2016-02-15	1600000.00	1324	2016-02-17	7
1	1324	2016-02-17	1700000.00	1325	2016-02-19	2
1	1325	2016-02-19	1700000.00	1326	2016-02-22	1
1	1326	2016-02-22	4800000.00	1327	2016-02-24	0
1	1327	2016-02-24	1700000.00	1328	2016-02-26	3
1	1328	2016-02-26	1700000.00	1329	2016-02-29	1
1	1329	2016-02-29	1700000.00	1330	2016-03-02	4
1	1330	2016-03-02	4500000.00	1331	2016-03-04	0
1	1331	2016-03-04	1700000.00	1332	2016-03-07	6
1	1332	2016-03-07	1700000.00	1333	2016-03-09	1
1	1333	2016-03-09	1700000.00	1334	2016-03-11	3
1	1334	2016-03-11	1700000.00	1335	2016-03-14	1
1	1335	2016-03-14	1700000.00	1336	2016-03-16	10
1	1336	2016-03-16	1700000.00	1337	2016-03-18	1
1	1337	2016-03-18	1700000.00	1338	2016-03-21	22
1	1338	2016-03-21	1700000.00	1339	2016-03-23	2
1	1339	2016-03-23	4500000.00	1340	2016-03-26	0
1	1340	2016-03-26	1700000.00	1341	2016-03-28	3
1	1341	2016-03-28	1700000.00	1342	2016-03-30	2
1	1342	2016-03-30	1700000.00	1343	2016-04-01	1
1	1343	2016-04-01	1700000.00	1344	2016-04-04	2
1	1344	2016-04-04	1700000.00	1345	2016-04-06	4
1	1345	2016-04-06	1700000.00	1346	2016-04-08	2
1	1346	2016-04-08	1700000.00	1347	2016-04-11	8
1	1347	2016-04-11	1700000.00	1348	2016-04-13	2
1	1348	2016-04-13	1700000.00	1349	2016-04-15	2
1	1349	2016-04-15	1700000.00	1350	2016-04-18	3
1	1350	2016-04-18	1700000.00	1351	2016-04-20	1
1	1351	2016-04-20	1500000.00	1352	2016-04-22	3
1	1352	2016-04-22	1700000.00	1353	2016-04-25	2
1	1353	2016-04-25	1700000.00	1354	2016-04-27	1
1	1354	2016-04-27	1700000.00	1355	2016-04-29	1
1	1355	2016-04-29	5000000.00	1356	2016-05-02	0
1	1356	2016-05-02	1700000.00	1357	2016-05-04	2
1	1357	2016-05-04	1700000.00	1358	2016-05-06	4
1	1358	2016-05-06	5000000.00	1359	2016-05-09	0
1	1359	2016-05-09	1700000.00	1360	2016-05-11	11
1	1360	2016-05-11	1700000.00	1361	2016-05-13	2
1	1361	2016-05-13	1700000.00	1362	2016-05-16	5
1	1362	2016-05-16	1700000.00	1363	2016-05-18	2
1	1363	2016-05-18	1700000.00	1364	2016-05-20	3
1	1364	2016-05-20	1700000.00	1365	2016-05-23	3
1	1365	2016-05-23	1700000.00	1366	2016-05-25	1
1	1366	2016-05-25	1200000.00	1367	2016-05-27	2
1	1367	2016-05-27	4200000.00	1368	2016-05-30	0
1	1368	2016-05-30	1700000.00	1369	2016-06-01	6
1	1369	2016-06-01	1700000.00	1370	2016-06-03	2
1	1370	2016-06-03	1700000.00	1371	2016-06-06	10
1	1371	2016-06-06	1700000.00	1372	2016-06-08	1
1	1372	2016-06-08	1700000.00	1373	2016-06-10	8
1	1373	2016-06-10	1700000.00	1374	2016-06-13	1
1	1374	2016-06-13	1700000.00	1375	2016-06-15	4
1	1375	2016-06-15	1700000.00	1376	2016-06-17	4
1	1376	2016-06-17	1700000.00	1377	2016-06-20	1
1	1377	2016-06-20	1700000.00	1378	2016-06-22	4
1	1378	2016-06-22	1700000.00	1379	2016-06-24	2
1	1379	2016-06-24	1700000.00	1380	2016-06-27	1
1	1380	2016-06-27	3700000.00	1381	2016-06-29	0
1	1381	2016-06-29	7000000.00	1382	2016-07-01	0
1	1382	2016-07-01	1700000.00	1383	2016-07-04	3
1	1383	2016-07-04	1700000.00	1384	2016-07-06	2
1	1384	2016-07-06	1700000.00	1385	2016-07-08	2
1	1385	2016-07-08	1700000.00	1386	2016-07-11	2
1	1386	2016-07-11	1700000.00	1387	2016-07-13	4
1	1387	2016-07-13	1700000.00	1388	2016-07-15	2
1	1388	2016-07-15	1700000.00	1389	2016-07-18	13
1	1389	2016-07-18	1700000.00	1390	2016-07-20	7
1	1390	2016-07-20	1700000.00	1391	2016-07-22	2
1	1391	2016-07-22	1700000.00	1392	2016-07-25	4
1	1392	2016-07-25	1700000.00	1393	2016-07-27	1
1	1393	2016-07-27	1700000.00	1394	2016-07-29	7
1	1394	2016-07-29	1700000.00	1395	2016-08-01	4
1	1395	2016-08-01	1700000.00	1396	2016-08-03	2
1	1396	2016-08-03	1700000.00	1397	2016-08-05	5
1	1397	2016-08-05	1700000.00	1398	2016-08-08	1
1	1398	2016-08-08	1700000.00	1399	2016-08-10	5
1	1399	2016-08-10	1700000.00	1400	2016-08-12	2
1	1400	2016-08-12	1700000.00	1401	2016-08-15	4
1	1401	2016-08-15	1700000.00	1402	2016-08-17	4
1	1402	2016-08-17	1700000.00	1403	2016-08-19	1
1	1403	2016-08-19	1700000.00	1404	2016-08-22	1
1	1404	2016-08-22	4500000.00	1405	2016-08-24	0
1	1405	2016-08-24	1700000.00	1406	2016-08-26	4
1	1406	2016-08-26	1700000.00	1407	2016-08-29	3
1	1407	2016-08-29	85000000.00	1408	2016-09-06	0
1	1408	2016-09-06	1700000.00	1409	2016-09-09	10
1	1409	2016-09-09	1700000.00	1410	2016-09-12	10
1	1410	2016-09-12	1700000.00	1411	2016-09-14	1
1	1411	2016-09-14	1700000.00	1412	2016-09-16	2
1	1412	2016-09-16	1700000.00	1413	2016-09-19	5
1	1413	2016-09-19	1700000.00	1414	2016-09-21	3
1	1414	2016-09-21	1700000.00	1415	2016-09-23	4
1	1415	2016-09-23	1700000.00	1416	2016-09-26	5
1	1416	2016-09-26	1700000.00	1417	2016-09-28	1
1	1417	2016-09-28	1700000.00	1418	2016-09-30	4
1	1418	2016-09-30	1700000.00	1419	2016-10-03	4
1	1419	2016-10-03	1700000.00	1420	2016-10-05	4
1	1420	2016-10-05	1700000.00	1421	2016-10-07	3
1	1421	2016-10-07	1700000.00	1422	2016-10-10	5
1	1422	2016-10-10	1700000.00	1423	2016-10-14	3
1	1423	2016-10-14	1700000.00	1424	2016-10-17	1
1	1424	2016-10-17	1700000.00	1425	2016-10-19	8
1	1425	2016-10-19	4500000.00	1426	2016-10-21	0
1	1426	2016-10-21	1700000.00	1427	2016-10-24	11
1	1427	2016-10-24	1700000.00	1428	2016-10-26	2
1	1428	2016-10-26	4000000.00	1429	2016-10-28	0
1	1429	2016-10-28	1700000.00	1430	2016-10-31	3
1	1430	2016-10-31	1700000.00	1431	2016-11-04	2
1	1431	2016-11-04	1700000.00	1432	2016-11-07	1
1	1432	2016-11-07	1700000.00	1433	2016-11-09	5
1	1433	2016-11-09	1700000.00	1434	2016-11-11	3
1	1434	2016-11-11	1700000.00	1435	2016-11-14	4
1	1435	2016-11-14	3500000.00	1436	2016-11-16	0
1	1436	2016-11-16	1700000.00	1437	2016-11-18	1
1	1437	2016-11-18	1700000.00	1438	2016-11-21	3
1	1438	2016-11-21	4700000.00	1439	2016-11-23	0
1	1439	2016-11-23	1700000.00	1440	2016-11-25	5
1	1440	2016-11-25	1700000.00	1441	2016-11-28	1
1	1441	2016-11-28	1700000.00	1442	2016-11-30	2
1	1442	2016-11-30	1700000.00	1443	2016-12-02	2
1	1443	2016-12-02	1700000.00	1444	2016-12-05	2
1	1444	2016-12-05	1700000.00	1445	2016-12-07	3
1	1445	2016-12-07	1700000.00	1446	2016-12-09	3
1	1446	2016-12-09	5200000.00	1447	2016-12-12	0
1	1447	2016-12-12	1700000.00	1448	2016-12-14	5
1	1448	2016-12-14	1700000.00	1449	2016-12-16	2
1	1449	2016-12-16	1700000.00	1450	2016-12-19	4
1	1450	2016-12-19	1700000.00	1451	2016-12-21	1
1	1451	2016-12-21	1700000.00	1452	2016-12-23	2
1	1452	2016-12-23	1700000.00	1453	2016-12-26	8
1	1453	2016-12-26	1700000.00	1454	2016-12-28	5
1	1454	2016-12-28	1700000.00	1455	2016-12-30	1
1	1455	2016-12-30	1700000.00	1456	2017-01-02	4
1	1456	2017-01-02	1700000.00	1457	2017-01-04	2
1	1457	2017-01-04	1700000.00	1458	2017-01-06	1
1	1458	2017-01-06	1700000.00	1459	2017-01-09	5
1	1459	2017-01-09	1700000.00	1460	2017-01-11	2
1	1460	2017-01-11	1700000.00	1461	2017-01-13	1
1	1461	2017-01-13	1700000.00	1462	2017-01-16	3
1	1462	2017-01-16	1700000.00	1463	2017-01-18	7
1	1463	2017-01-18	1700000.00	1464	2017-01-20	8
1	1464	2017-01-20	1700000.00	1465	2017-01-23	1
1	1465	2017-01-23	1700000.00	1466	2017-01-25	2
1	1466	2017-01-25	1700000.00	1467	2017-01-27	1
1	1467	2017-01-27	1700000.00	1468	2017-01-30	8
1	1468	2017-01-30	1700000.00	1469	2017-02-01	4
1	1469	2017-02-01	1700000.00	1470	2017-02-03	2
1	1470	2017-02-03	1700000.00	1471	2017-02-06	2
1	1471	2017-02-06	1700000.00	1472	2017-02-08	2
1	1472	2017-02-08	1700000.00	1473	2017-02-10	2
1	1473	2017-02-10	1700000.00	1474	2017-02-13	1
1	1474	2017-02-13	1700000.00	1475	2017-02-15	5
1	1475	2017-02-15	1700000.00	1476	2017-02-17	5
1	1476	2017-02-17	1700000.00	1477	2017-02-20	4
1	1477	2017-02-20	1700000.00	1478	2017-02-22	3
1	1478	2017-02-22	1700000.00	1479	2017-02-24	3
1	1479	2017-02-24	1500000.00	1480	2017-03-01	2
1	1480	2017-03-01	4500000.00	1481	2017-03-03	0
1	1481	2017-03-03	1700000.00	1482	2017-03-06	3
1	1482	2017-03-06	1700000.00	1483	2017-03-08	2
1	1483	2017-03-08	1700000.00	1484	2017-03-10	2
1	1484	2017-03-10	1700000.00	1485	2017-03-13	2
1	1485	2017-03-13	1700000.00	1486	2017-03-15	4
1	1486	2017-03-15	1700000.00	1487	2017-03-17	1
1	1487	2017-03-17	1700000.00	1488	2017-03-20	3
1	1488	2017-03-20	1700000.00	1489	2017-03-22	4
1	1489	2017-03-22	1700000.00	1490	2017-03-24	3
1	1490	2017-03-24	1700000.00	1491	2017-03-27	2
1	1491	2017-03-27	1700000.00	1492	2017-03-29	1
1	1492	2017-03-29	1700000.00	1493	2017-03-31	2
1	1493	2017-03-31	1700000.00	1494	2017-04-03	9
1	1494	2017-04-03	1700000.00	1495	2017-04-05	3
1	1495	2017-04-05	1700000.00	1496	2017-04-07	3
1	1496	2017-04-07	1700000.00	1497	2017-04-10	1
1	1497	2017-04-10	1700000.00	1498	2017-04-12	1
1	1498	2017-04-12	1700000.00	1499	2017-04-15	1
1	1499	2017-04-15	1000000.00	1500	2017-04-17	2
1	1500	2017-04-17	1700000.00	1501	2017-04-19	3
1	1501	2017-04-19	1700000.00	1502	2017-04-22	2
1	1502	2017-04-22	3500000.00	1503	2017-04-24	0
1	1503	2017-04-24	5800000.00	1504	2017-04-26	0
1	1504	2017-04-26	1700000.00	1505	2017-04-28	2
1	1505	2017-04-28	2000000.00	1506	2017-05-03	1
1	1506	2017-05-03	1700000.00	1507	2017-05-05	2
1	1507	2017-05-05	1700000.00	1508	2017-05-08	6
1	1508	2017-05-08	1700000.00	1509	2017-05-10	2
1	1509	2017-05-10	1700000.00	1510	2017-05-12	5
1	1510	2017-05-12	1700000.00	1511	2017-05-15	4
1	1511	2017-05-15	1700000.00	1512	2017-05-17	5
1	1512	2017-05-17	1700000.00	1513	2017-05-19	1
1	1513	2017-05-19	1700000.00	1514	2017-05-22	1
1	1514	2017-05-22	1700000.00	1515	2017-05-24	2
1	1515	2017-05-24	1700000.00	1516	2017-05-26	5
1	1516	2017-05-26	1700000.00	1517	2017-05-29	3
1	1517	2017-05-29	1700000.00	1518	2017-05-31	4
1	1518	2017-05-31	1700000.00	1519	2017-06-02	4
1	1519	2017-06-02	1700000.00	1520	2017-06-05	4
1	1520	2017-06-05	1700000.00	1521	2017-06-07	6
1	1521	2017-06-07	1700000.00	1522	2017-06-09	4
1	1522	2017-06-09	1700000.00	1523	2017-06-12	2
1	1523	2017-06-12	1700000.00	1524	2017-06-14	8
1	1524	2017-06-14	1700000.00	1525	2017-06-16	1
1	1525	2017-06-16	1700000.00	1526	2017-06-19	3
1	1526	2017-06-19	1700000.00	1527	2017-06-21	7
1	1527	2017-06-21	1700000.00	1528	2017-06-23	1
1	1528	2017-06-23	4800000.00	1529	2017-06-26	0
1	1529	2017-06-26	1700000.00	1530	2017-06-28	3
1	1530	2017-06-28	1700000.00	1531	2017-06-30	41
1	1531	2017-06-30	1700000.00	1532	2017-07-03	1
1	1532	2017-07-03	1700000.00	1533	2017-07-05	3
1	1533	2017-07-05	1700000.00	1534	2017-07-07	2
1	1534	2017-07-07	1700000.00	1535	2017-07-10	1
1	1535	2017-07-10	1700000.00	1536	2017-07-12	5
1	1536	2017-07-12	1700000.00	1537	2017-07-14	1
1	1537	2017-07-14	1700000.00	1538	2017-07-17	1
1	1538	2017-07-17	1700000.00	1539	2017-07-19	1
1	1539	2017-07-19	1700000.00	1540	2017-07-21	2
1	1540	2017-07-21	1700000.00	1541	2017-07-24	2
1	1541	2017-07-24	1700000.00	1542	2017-07-26	1
1	1542	2017-07-26	1700000.00	1543	2017-07-28	17
1	1543	2017-07-28	1700000.00	1544	2017-07-31	4
1	1544	2017-07-31	1700000.00	1545	2017-08-02	2
1	1545	2017-08-02	1700000.00	1546	2017-08-04	2
1	1546	2017-08-04	1700000.00	1547	2017-08-07	1
1	1547	2017-08-07	1700000.00	1548	2017-08-09	7
1	1548	2017-08-09	1700000.00	1549	2017-08-11	3
1	1549	2017-08-11	1700000.00	1550	2017-08-14	5
1	1550	2017-08-14	1700000.00	1551	2017-08-16	1
1	1551	2017-08-16	1700000.00	1552	2017-08-18	13
1	1552	2017-08-18	1700000.00	1553	2017-08-21	6
1	1553	2017-08-21	1700000.00	1554	2017-08-23	10
1	1554	2017-08-23	1700000.00	1555	2017-08-25	1
1	1555	2017-08-25	1700000.00	1556	2017-08-28	6
1	1556	2017-08-28	80000000.00	1557	2017-09-06	2
1	1557	2017-09-07	2000000.00	1558	2017-09-11	15
1	1558	2017-09-11	1700000.00	1559	2017-09-13	1
1	1559	2017-09-13	1700000.00	1560	2017-09-15	1
1	1560	2017-09-15	1700000.00	1561	2017-09-18	3
1	1561	2017-09-18	1700000.00	1562	2017-09-20	4
1	1562	2017-09-20	1700000.00	1563	2017-09-22	9
1	1563	2017-09-22	1700000.00	1564	2017-09-25	3
1	1564	2017-09-25	1700000.00	1565	2017-09-27	1
1	1565	2017-09-27	4500000.00	1566	2017-09-29	0
1	1566	2017-09-29	1700000.00	1567	2017-10-02	4
1	1567	2017-10-02	1700000.00	1568	2017-10-04	4
1	1568	2017-10-04	1700000.00	1569	2017-10-06	7
1	1569	2017-10-06	1700000.00	1570	2017-10-09	3
1	1570	2017-10-09	1700000.00	1571	2017-10-11	2
1	1571	2017-10-11	1700000.00	1572	2017-10-13	1
1	1572	2017-10-13	1700000.00	1573	2017-10-16	1
1	1573	2017-10-16	1700000.00	1574	2017-10-18	4
1	1574	2017-10-18	1700000.00	1575	2017-10-20	3
1	1575	2017-10-20	1700000.00	1576	2017-10-23	2
1	1576	2017-10-23	1700000.00	1577	2017-10-25	6
1	1577	2017-10-25	1700000.00	1578	2017-10-27	2
1	1578	2017-10-27	1700000.00	1579	2017-10-30	2
1	1579	2017-10-30	5100000.00	1580	2017-11-01	0
1	1580	2017-11-01	1700000.00	1581	2017-11-03	4
1	1581	2017-11-03	1700000.00	1582	2017-11-06	2
1	1582	2017-11-06	1700000.00	1583	2017-11-08	4
1	1583	2017-11-08	1700000.00	1584	2017-11-10	2
1	1584	2017-11-10	5700000.00	1585	2017-11-13	0
1	1585	2017-11-13	1700000.00	1586	2017-11-16	1
1	1586	2017-11-16	1000000.00	1587	2017-11-17	1
1	1587	2017-11-17	1700000.00	1588	2017-11-20	5
1	1588	2017-11-20	1700000.00	1589	2017-11-22	4
1	1589	2017-11-22	1700000.00	1590	2017-11-24	2
1	1590	2017-11-24	1700000.00	1591	2017-11-27	1
1	1591	2017-11-27	1700000.00	1592	2017-11-29	1
1	1592	2017-11-29	5000000.00	1593	2017-12-01	0
1	1593	2017-12-01	1700000.00	1594	2017-12-04	3
1	1594	2017-12-04	1700000.00	1595	2017-12-06	4
1	1595	2017-12-06	1700000.00	1596	2017-12-08	3
1	1596	2017-12-08	1700000.00	1597	2017-12-11	4
1	1597	2017-12-11	1700000.00	1598	2017-12-13	4
1	1598	2017-12-13	1700000.00	1599	2017-12-15	2
1	1599	2017-12-15	1700000.00	1600	2017-12-18	1
1	1600	2017-12-18	1700000.00	1601	2017-12-20	1
1	1601	2017-12-20	1700000.00	1602	2017-12-22	3
1	1602	2017-12-22	1700000.00	1603	2017-12-26	8
1	1603	2017-12-26	1200000.00	1604	2017-12-27	5
1	1604	2017-12-27	1700000.00	1605	2017-12-29	2
1	1605	2017-12-29	1700000.00	1606	2018-01-02	4
1	1606	2018-01-02	1200000.00	1607	2018-01-03	5
1	1607	2018-01-03	3000000.00	1608	2018-01-05	0
1	1608	2018-01-05	1700000.00	1609	2018-01-08	5
1	1609	2018-01-08	1700000.00	1610	2018-01-10	2
1	1610	2018-01-10	1700000.00	1611	2018-01-12	6
1	1611	2018-01-12	1700000.00	1612	2018-01-15	1
1	1612	2018-01-15	4500000.00	1613	2018-01-17	0
1	1613	2018-01-17	1700000.00	1614	2018-01-19	5
1	1614	2018-01-19	1700000.00	1615	2018-01-22	3
1	1615	2018-01-22	1700000.00	1616	2018-01-24	3
1	1616	2018-01-24	5000000.00	1617	2018-01-26	0
1	1617	2018-01-26	1700000.00	1618	2018-01-29	1
1	1618	2018-01-29	1700000.00	1619	2018-01-31	4
1	1619	2018-01-31	1700000.00	1620	2018-02-02	1
1	1620	2018-02-02	1700000.00	1621	2018-02-05	4
1	1621	2018-02-05	1700000.00	1622	2018-02-07	7
1	1622	2018-02-07	1700000.00	1623	2018-02-09	1
1	1623	2018-02-09	1500000.00	1624	2018-02-14	5
1	1624	2018-02-14	5500000.00	1625	2018-02-16	0
1	1625	2018-02-16	1700000.00	1626	2018-02-19	4
1	1626	2018-02-19	1700000.00	1627	2018-02-21	5
1	1627	2018-02-21	1700000.00	1628	2018-02-23	1
1	1628	2018-02-23	1700000.00	1629	2018-02-26	2
1	1629	2018-02-26	1700000.00	1630	2018-02-28	4
1	1630	2018-02-28	1700000.00	1631	2018-03-02	4
1	1631	2018-03-02	1700000.00	1632	2018-03-05	6
1	1632	2018-03-05	5000000.00	1633	2018-03-07	0
1	1633	2018-03-07	1700000.00	1634	2018-03-09	3
1	1634	2018-03-09	1700000.00	1635	2018-03-12	2
1	1635	2018-03-12	1700000.00	1636	2018-03-14	2
1	1636	2018-03-14	1700000.00	1637	2018-03-16	1
1	1637	2018-03-16	1700000.00	1638	2018-03-19	6
1	1638	2018-03-19	5300000.00	1639	2018-03-21	0
1	1639	2018-03-21	1700000.00	1640	2018-03-23	6
1	1640	2018-03-23	1700000.00	1641	2018-03-26	3
1	1641	2018-03-26	1700000.00	1642	2018-03-28	5
1	1642	2018-03-28	1700000.00	1643	2018-03-31	5
1	1643	2018-03-31	1700000.00	1644	2018-04-02	2
1	1644	2018-04-02	1700000.00	1645	2018-04-04	2
1	1645	2018-04-04	1700000.00	1646	2018-04-06	3
1	1646	2018-04-06	1700000.00	1647	2018-04-09	6
1	1647	2018-04-09	1700000.00	1648	2018-04-11	5
1	1648	2018-04-11	1700000.00	1649	2018-04-13	1
1	1649	2018-04-13	1700000.00	1650	2018-04-16	2
1	1650	2018-04-16	4500000.00	1651	2018-04-18	0
1	1651	2018-04-18	1700000.00	1652	2018-04-20	4
1	1652	2018-04-20	4000000.00	1653	2018-04-23	0
1	1653	2018-04-23	7500000.00	1654	2018-04-25	0
1	1654	2018-04-25	1700000.00	1655	2018-04-27	5
1	1655	2018-04-27	1700000.00	1656	2018-04-30	2
1	1656	2018-04-30	1200000.00	1657	2018-05-02	3
1	1657	2018-05-02	4500000.00	1658	2018-05-04	0
1	1658	2018-05-04	1700000.00	1659	2018-05-07	5
1	1659	2018-05-07	1700000.00	1660	2018-05-09	2
1	1660	2018-05-09	1700000.00	1661	2018-05-11	25
1	1661	2018-05-11	1700000.00	1662	2018-05-14	4
1	1662	2018-05-14	1700000.00	1663	2018-05-16	8
1	1663	2018-05-16	1700000.00	1664	2018-05-18	7
1	1664	2018-05-18	1700000.00	1665	2018-05-21	4
1	1665	2018-05-21	1700000.00	1666	2018-05-23	1
1	1666	2018-05-23	1700000.00	1667	2018-05-25	3
1	1667	2018-05-25	1700000.00	1668	2018-05-28	6
1	1668	2018-05-28	1700000.00	1669	2018-05-30	3
1	1669	2018-05-30	1700000.00	1670	2018-06-01	2
1	1670	2018-06-01	1700000.00	1671	2018-06-04	3
1	1671	2018-06-04	1700000.00	1672	2018-06-06	3
1	1672	2018-06-06	1700000.00	1673	2018-06-08	2
1	1673	2018-06-08	1700000.00	1674	2018-06-11	6
1	1674	2018-06-11	1700000.00	1675	2018-06-13	2
1	1675	2018-06-13	1700000.00	1676	2018-06-15	1
1	1676	2018-06-15	1700000.00	1677	2018-06-18	4
1	1677	2018-06-18	1700000.00	1678	2018-06-20	4
1	1678	2018-06-20	4800000.00	1679	2018-06-22	0
1	1679	2018-06-22	1700000.00	1680	2018-06-25	7
1	1680	2018-06-25	1700000.00	1681	2018-06-27	2
1	1681	2018-06-27	1700000.00	1682	2018-06-29	8
1	1682	2018-06-29	1700000.00	1683	2018-07-02	3
1	1683	2018-07-02	1700000.00	1684	2018-07-04	3
1	1684	2018-07-04	1700000.00	1685	2018-07-06	4
1	1685	2018-07-06	1700000.00	1686	2018-07-09	3
1	1686	2018-07-09	1700000.00	1687	2018-07-11	3
1	1687	2018-07-11	1700000.00	1688	2018-07-13	2
1	1688	2018-07-13	5000000.00	1689	2018-07-16	0
1	1689	2018-07-16	1700000.00	1690	2018-07-18	2
1	1690	2018-07-18	1700000.00	1691	2018-07-20	5
1	1691	2018-07-20	1700000.00	1692	2018-07-23	2
1	1692	2018-07-23	1700000.00	1693	2018-07-25	5
1	1693	2018-07-25	1700000.00	1694	2018-07-27	1
1	1694	2018-07-27	1700000.00	1695	2018-07-30	1
1	1695	2018-07-30	1700000.00	1696	2018-08-01	1
1	1696	2018-08-01	1700000.00	1697	2018-08-03	4
1	1697	2018-08-03	2000000.00	1698	2018-08-06	1
1	1698	2018-08-06	2000000.00	1699	2018-08-08	1
1	1699	2018-08-08	2000000.00	1700	2018-08-10	4
1	1700	2018-08-10	2000000.00	1701	2018-08-13	4
1	1701	2018-08-13	2000000.00	1702	2018-08-15	3
1	1702	2018-08-15	2000000.00	1703	2018-08-17	2
1	1703	2018-08-17	2000000.00	1704	2018-08-20	2
1	1704	2018-08-20	2000000.00	1705	2018-08-22	1
1	1705	2018-08-22	2000000.00	1706	2018-08-24	2
1	1706	2018-08-24	2000000.00	1707	2018-08-27	7
1	1707	2018-08-27	85000000.00	1708	2018-09-08	1
1	1708	2018-09-08	1200000.00	1709	2018-09-10	33
1	1709	2018-09-10	2000000.00	1710	2018-09-12	1
1	1710	2018-09-12	1700000.00	1711	2018-09-14	2
1	1711	2018-09-14	2000000.00	1712	2018-09-17	3
1	1712	2018-09-17	2000000.00	1713	2018-09-19	14
1	1713	2018-09-19	2000000.00	1714	2018-09-21	3
1	1714	2018-09-21	2000000.00	1715	2018-09-24	2
1	1715	2018-09-24	2000000.00	1716	2018-09-26	4
1	1716	2018-09-26	4500000.00	1717	2018-09-28	0
1	1717	2018-09-28	2000000.00	1718	2018-10-01	2
1	1718	2018-10-01	2000000.00	1719	2018-10-03	7
1	1719	2018-10-03	2000000.00	1720	2018-10-05	1
1	1720	2018-10-05	2000000.00	1721	2018-10-08	11
1	1721	2018-10-08	2000000.00	1722	2018-10-10	2
1	1722	2018-10-10	1700000.00	1723	2018-10-13	8
1	1723	2018-10-13	2000000.00	1724	2018-10-15	6
1	1724	2018-10-15	2000000.00	1725	2018-10-17	3
1	1725	2018-10-17	2000000.00	1726	2018-10-19	2
1	1726	2018-10-19	2000000.00	1727	2018-10-22	23
1	1727	2018-10-22	2000000.00	1728	2018-10-24	2
1	1728	2018-10-24	2000000.00	1729	2018-10-26	1
1	1729	2018-10-26	2000000.00	1730	2018-10-29	7
1	1730	2018-10-29	2000000.00	1731	2018-10-31	2
1	1731	2018-10-31	2000000.00	1732	2018-11-03	8
1	1732	2018-11-03	1500000.00	1733	2018-11-05	2
1	1733	2018-11-05	2000000.00	1734	2018-11-07	4
1	1734	2018-11-07	2000000.00	1735	2018-11-09	4
1	1735	2018-11-09	2000000.00	1736	2018-11-12	1
1	1736	2018-11-12	2000000.00	1737	2018-11-14	4
1	1737	2018-11-14	1200000.00	1738	2018-11-16	3
1	1738	2018-11-16	2000000.00	1739	2018-11-19	1
1	1739	2018-11-19	2000000.00	1740	2018-11-21	1
1	1740	2018-11-21	2000000.00	1741	2018-11-23	2
1	1741	2018-11-23	2000000.00	1742	2018-11-26	3
1	1742	2018-11-26	4500000.00	1743	2018-11-28	0
1	1743	2018-11-28	2000000.00	1744	2018-11-30	5
1	1744	2018-11-30	4500000.00	1745	2018-12-03	0
1	1745	2018-12-03	2000000.00	1746	2018-12-05	3
1	1746	2018-12-05	2000000.00	1747	2018-12-07	1
1	1747	2018-12-07	2000000.00	1748	2018-12-10	1
1	1748	2018-12-10	2000000.00	1749	2018-12-12	2
1	1749	2018-12-12	2000000.00	1750	2018-12-14	5
1	1750	2018-12-14	2000000.00	1751	2018-12-17	3
1	1751	2018-12-17	2000000.00	1752	2018-12-19	14
1	1752	2018-12-19	2000000.00	1753	2018-12-21	2
1	1753	2018-12-21	1500000.00	1754	2018-12-24	3
1	1754	2018-12-24	2000000.00	1755	2018-12-26	2
1	1755	2018-12-26	2000000.00	1756	2018-12-28	2
1	1756	2018-12-28	1700000.00	1757	2018-12-31	6
1	1757	2018-12-31	3800000.00	1758	2019-01-02	0
1	1758	2019-01-02	2000000.00	1759	2019-01-04	5
1	1759	2019-01-04	5000000.00	1760	2019-01-07	0
1	1760	2019-01-07	2000000.00	1761	2019-01-09	6
1	1761	2019-01-09	2000000.00	1762	2019-01-11	4
1	1762	2019-01-11	2000000.00	1763	2019-01-14	6
1	1763	2019-01-14	1700000.00	1764	2019-01-16	1
1	1764	2019-01-16	2000000.00	1765	2019-01-18	4
1	1765	2019-01-18	2000000.00	1766	2019-01-21	8
1	1766	2019-01-21	2000000.00	1767	2019-01-23	1
1	1767	2019-01-23	2000000.00	1768	2019-01-25	1
1	1768	2019-01-25	2000000.00	1769	2019-01-28	1
1	1769	2019-01-28	2000000.00	1770	2019-01-30	7
1	1770	2019-01-30	2000000.00	1771	2019-02-01	2
1	1771	2019-02-01	1700000.00	1772	2019-02-04	1
1	1772	2019-02-04	2000000.00	1773	2019-02-06	4
1	1773	2019-02-06	2000000.00	1774	2019-02-08	1
1	1774	2019-02-08	2000000.00	1775	2019-02-11	7
1	1775	2019-02-11	2000000.00	1776	2019-02-13	3
1	1776	2019-02-13	2000000.00	1777	2019-02-15	9
1	1777	2019-02-15	2000000.00	1778	2019-02-18	16
1	1778	2019-02-18	2000000.00	1779	2019-02-20	12
1	1779	2019-02-20	2000000.00	1780	2019-02-22	3
1	1780	2019-02-22	2000000.00	1781	2019-02-25	2
1	1781	2019-02-25	2000000.00	1782	2019-02-27	3
1	1782	2019-02-27	2000000.00	1783	2019-03-01	2
1	1783	2019-03-01	2000000.00	1784	2019-03-06	5
1	1784	2019-03-06	2000000.00	1785	2019-03-08	50
1	1785	2019-03-08	2000000.00	1786	2019-03-11	2
1	1786	2019-03-11	2000000.00	1787	2019-03-13	1
1	1787	2019-03-13	2000000.00	1788	2019-03-15	9
1	1788	2019-03-15	2000000.00	1789	2019-03-18	1
1	1789	2019-03-18	2000000.00	1790	2019-03-20	11
1	1790	2019-03-20	2000000.00	1791	2019-03-22	2
1	1791	2019-03-22	2000000.00	1792	2019-03-25	2
1	1792	2019-03-25	2000000.00	1793	2019-03-27	1
1	1793	2019-03-27	2000000.00	1794	2019-03-29	1
1	1794	2019-03-29	2000000.00	1795	2019-04-01	1
1	1795	2019-04-01	2000000.00	1796	2019-04-03	4
1	1796	2019-04-03	2000000.00	1797	2019-04-05	3
1	1797	2019-04-05	2000000.00	1798	2019-04-08	3
1	1798	2019-04-08	2000000.00	1799	2019-04-10	2
1	1799	2019-04-10	2000000.00	1800	2019-04-12	3
1	1800	2019-04-12	2000000.00	1801	2019-04-15	4
1	1801	2019-04-15	2000000.00	1802	2019-04-17	8
1	1802	2019-04-17	2000000.00	1803	2019-04-20	2
1	1803	2019-04-20	1500000.00	1804	2019-04-22	3
1	1804	2019-04-22	2000000.00	1805	2019-04-24	4
1	1805	2019-04-24	2000000.00	1806	2019-04-26	2
1	1806	2019-04-26	2000000.00	1807	2019-04-29	6
1	1807	2019-04-29	2000000.00	1808	2019-05-02	2
1	1808	2019-05-02	1500000.00	1809	2019-05-03	1
1	1809	2019-05-03	2000000.00	1810	2019-05-06	4
1	1810	2019-05-06	2000000.00	1811	2019-05-08	9
1	1811	2019-05-08	2000000.00	1812	2019-05-10	1
1	1812	2019-05-10	2000000.00	1813	2019-05-13	6
1	1813	2019-05-13	2000000.00	1814	2019-05-15	2
1	1814	2019-05-15	2000000.00	1815	2019-05-17	3
1	1815	2019-05-17	2000000.00	1816	2019-05-20	1
1	1816	2019-05-20	2000000.00	1817	2019-05-22	2
1	1817	2019-05-22	2000000.00	1818	2019-05-24	1
1	1818	2019-05-24	2000000.00	1819	2019-05-27	4
1	1819	2019-05-27	2000000.00	1820	2019-05-29	2
1	1820	2019-05-29	2000000.00	1821	2019-05-31	2
1	1821	2019-05-31	4500000.00	1822	2019-06-03	0
1	1822	2019-06-03	2000000.00	1823	2019-06-05	2
1	1823	2019-06-05	2000000.00	1824	2019-06-07	1
1	1824	2019-06-07	2000000.00	1825	2019-06-10	14
1	1825	2019-06-10	2000000.00	1826	2019-06-12	1
1	1826	2019-06-12	2000000.00	1827	2019-06-14	1
1	1827	2019-06-14	2000000.00	1828	2019-06-17	14
1	1828	2019-06-17	4500000.00	1829	2019-06-19	0
1	1829	2019-06-19	1500000.00	1830	2019-06-21	4
1	1830	2019-06-21	2000000.00	1831	2019-06-24	7
1	1831	2019-06-24	2000000.00	1832	2019-06-26	3
1	1832	2019-06-26	2000000.00	1833	2019-06-28	2
1	1833	2019-06-28	2000000.00	1834	2019-07-01	2
1	1834	2019-07-01	2000000.00	1835	2019-07-03	1
1	1835	2019-07-03	2000000.00	1836	2019-07-05	5
1	1836	2019-07-05	2000000.00	1837	2019-07-08	1
1	1837	2019-07-08	2000000.00	1838	2019-07-10	1
1	1838	2019-07-10	2000000.00	1839	2019-07-12	7
1	1839	2019-07-12	2000000.00	1840	2019-07-15	18
1	1840	2019-07-15	2000000.00	1841	2019-07-17	3
1	1841	2019-07-17	2000000.00	1842	2019-07-19	4
1	1842	2019-07-19	2000000.00	1843	2019-07-22	2
1	1843	2019-07-22	2000000.00	1844	2019-07-24	2
1	1844	2019-07-24	4500000.00	1845	2019-07-26	0
1	1845	2019-07-26	2000000.00	1846	2019-07-29	6
1	1846	2019-07-29	2000000.00	1847	2019-07-31	10
1	1847	2019-07-31	2000000.00	1848	2019-08-02	3
1	1848	2019-08-02	2000000.00	1849	2019-08-05	3
1	1849	2019-08-05	4500000.00	1850	2019-08-07	0
1	1850	2019-08-07	2000000.00	1851	2019-08-09	6
1	1851	2019-08-09	2000000.00	1852	2019-08-12	1
1	1852	2019-08-12	2000000.00	1853	2019-08-14	4
1	1853	2019-08-14	2000000.00	1854	2019-08-16	3
1	1854	2019-08-16	2000000.00	1855	2019-08-19	5
1	1855	2019-08-19	2000000.00	1856	2019-08-21	2
1	1856	2019-08-21	2000000.00	1857	2019-08-23	3
1	1857	2019-08-23	5000000.00	1858	2019-08-26	0
1	1858	2019-08-26	2000000.00	1859	2019-08-28	10
1	1859	2019-08-28	2000000.00	1860	2019-08-30	5
1	1860	2019-08-30	95000000.00	1861	2019-09-06	2
1	1861	2019-09-06	2000000.00	1862	2019-09-09	33
1	1862	2019-09-09	2000000.00	1863	2019-09-11	4
1	1863	2019-09-11	2000000.00	1864	2019-09-13	1
1	1864	2019-09-13	2000000.00	1865	2019-09-16	1
1	1865	2019-09-16	2000000.00	1866	2019-09-18	7
1	1866	2019-09-18	2000000.00	1867	2019-09-20	2
1	1867	2019-09-20	2000000.00	1868	2019-09-23	1
1	1868	2019-09-23	2000000.00	1869	2019-09-25	3
1	1869	2019-09-25	2000000.00	1870	2019-09-27	1
1	1870	2019-09-27	2000000.00	1871	2019-09-30	1
1	1871	2019-09-30	2000000.00	1872	2019-10-02	2
1	1872	2019-10-02	5000000.00	1873	2019-10-04	0
1	1873	2019-10-04	2000000.00	1874	2019-10-07	7
1	1874	2019-10-07	2000000.00	1875	2019-10-09	1
1	1875	2019-10-09	5000000.00	1876	2019-10-11	0
1	1876	2019-10-11	2000000.00	1877	2019-10-14	4
1	1877	2019-10-14	2000000.00	1878	2019-10-16	1
1	1878	2019-10-16	2000000.00	1879	2019-10-18	3
1	1879	2019-10-18	2000000.00	1880	2019-10-21	34
1	1880	2019-10-21	2000000.00	1881	2019-10-23	4
1	1881	2019-10-23	5000000.00	1882	2019-10-25	0
1	1882	2019-10-25	2000000.00	1883	2019-10-28	1
1	1883	2019-10-28	2000000.00	1884	2019-10-30	1
1	1884	2019-10-30	2000000.00	1885	2019-11-01	2
1	1885	2019-11-01	2000000.00	1886	2019-11-04	6
1	1886	2019-11-04	2000000.00	1887	2019-11-06	1
1	1887	2019-11-06	2000000.00	1888	2019-11-09	1
1	1888	2019-11-09	1500000.00	1889	2019-11-11	6
1	1889	2019-11-11	2000000.00	1890	2019-11-13	2
1	1890	2019-11-13	2000000.00	1891	2019-11-16	1
1	1891	2019-11-16	2000000.00	1892	2019-11-18	4
1	1892	2019-11-18	2000000.00	1893	2019-11-20	1
1	1893	2019-11-21	2000000.00	1894	2019-11-22	3
1	1894	2019-11-22	2000000.00	1895	2019-11-25	4
1	1895	2019-11-25	2000000.00	1896	2019-11-27	1
1	1896	2019-11-27	2000000.00	1897	2019-11-29	2
1	1897	2019-11-29	6000000.00	1898	2019-12-02	0
1	1898	2019-12-02	2000000.00	1899	2019-12-04	4
1	1899	2019-12-04	6300000.00	1900	2019-12-06	0
1	1900	2019-12-06	2000000.00	1901	2019-12-09	4
1	1901	2019-12-09	2000000.00	1902	2019-12-11	2
1	1902	2019-12-11	2500000.00	1903	2019-12-13	3
1	1903	2019-12-13	2500000.00	1904	2019-12-16	1
1	1904	2019-12-16	2500000.00	1905	2019-12-18	1
1	1905	2019-12-18	2500000.00	1906	2019-12-20	2
1	1906	2019-12-20	2500000.00	1907	2019-12-23	3
1	1907	2019-12-23	2500000.00	1908	2019-12-26	4
1	1908	2019-12-26	2500000.00	1909	2019-12-28	3
1	1909	2019-12-28	1500000.00	1910	2019-12-30	1
1	1910	2019-12-30	2500000.00	1911	2020-01-03	3
1	1911	2020-01-03	2500000.00	1912	2020-01-06	2
1	1912	2020-01-06	2500000.00	1913	2020-01-08	1
1	1913	2020-01-08	2500000.00	1914	2020-01-10	2
1	1914	2020-01-10	6500000.00	1915	2020-01-13	0
1	1915	2020-01-13	2500000.00	1916	2020-01-15	5
1	1916	2020-01-15	2500000.00	1917	2020-01-17	4
1	1917	2020-01-17	2500000.00	1918	2020-01-20	1
1	1918	2020-01-20	2500000.00	1919	2020-01-22	5
1	1919	2020-01-22	2500000.00	1920	2020-01-24	3
1	1920	2020-01-24	2500000.00	1921	2020-01-27	4
1	1921	2020-01-27	2500000.00	1922	2020-01-29	5
1	1922	2020-01-29	2500000.00	1923	2020-01-31	1
1	1923	2020-01-31	2500000.00	1924	2020-02-03	16
1	1924	2020-02-03	2500000.00	1925	2020-02-05	3
1	1925	2020-02-05	2500000.00	1926	2020-02-07	1
1	1926	2020-02-07	2500000.00	1927	2020-02-10	4
1	1927	2020-02-10	2500000.00	1928	2020-02-12	4
1	1928	2020-02-12	2500000.00	1929	2020-02-14	1
1	1929	2020-02-14	2500000.00	1930	2020-02-17	5
1	1930	2020-02-17	2500000.00	1931	2020-02-19	2
1	1931	2020-02-19	2500000.00	1932	2020-02-21	4
1	1932	2020-02-21	2200000.00	1933	2020-02-26	20
1	1933	2020-02-26	2500000.00	1934	2020-02-28	1
1	1934	2020-02-28	2500000.00	1935	2020-03-02	4
1	1935	2020-03-02	2500000.00	1936	2020-03-04	3
1	1936	2020-03-04	2500000.00	1937	2020-03-06	4
1	1937	2020-03-06	2500000.00	1938	2020-03-09	4
1	1938	2020-03-09	2500000.00	1939	2020-03-11	2
1	1939	2020-03-11	2500000.00	1940	2020-03-13	6
1	1940	2020-03-13	5000000.00	1941	2020-03-16	0
1	1941	2020-03-16	2500000.00	1942	2020-03-18	9
1	1942	2020-03-18	2500000.00	1943	2020-03-20	2
1	1943	2020-03-20	1500000.00	1944	2020-03-23	2
1	1944	2020-03-23	1000000.00	1945	2020-03-25	11
1	1945	2020-03-25	1000000.00	1946	2020-03-27	5
1	1946	2020-03-27	1500000.00	1947	2020-03-30	1
1	1947	2020-03-30	1500000.00	1948	2020-04-01	2
1	1948	2020-04-01	1500000.00	1949	2020-04-03	3
1	1949	2020-04-03	1500000.00	1950	2020-04-06	5
1	1950	2020-04-06	1500000.00	1951	2020-04-08	2
1	1951	2020-04-08	1500000.00	1952	2020-04-11	4
1	1952	2020-04-11	1400000.00	1953	2020-04-13	6
1	1953	2020-04-13	1500000.00	1954	2020-04-15	1
1	1954	2020-04-15	1500000.00	1955	2020-04-17	2
1	1955	2020-04-17	1500000.00	1956	2020-04-20	2
1	1956	2020-04-20	4100000.00	1957	2020-04-22	0
1	1957	2020-04-22	1500000.00	1958	2020-04-24	1
1	1958	2020-04-24	1500000.00	1959	2020-04-27	4
1	1959	2020-04-27	4000000.00	1960	2020-04-29	0
1	1960	2020-04-29	1500000.00	1961	2020-05-02	10
1	1961	2020-05-02	1500000.00	1962	2020-05-04	2
1	1962	2020-05-04	1500000.00	1963	2020-05-06	1
1	1963	2020-05-06	1500000.00	1964	2020-05-08	3
1	1964	2020-05-08	5000000.00	1965	2020-05-11	0
1	1965	2020-05-11	9000000.00	1966	2020-05-13	0
1	1966	2020-05-13	1500000.00	1967	2020-05-15	3
1	1967	2020-05-15	1500000.00	1968	2020-05-18	2
1	1968	2020-05-18	1500000.00	1969	2020-05-20	2
1	1969	2020-05-20	1500000.00	1970	2020-05-22	7
1	1970	2020-05-22	5500000.00	1971	2020-05-25	0
1	1971	2020-05-25	9000000.00	1972	2020-05-27	0
1	1972	2020-05-28	1800000.00	1973	2020-05-29	2
1	1973	2020-05-29	2000000.00	1974	2020-06-01	2
1	1974	2020-06-01	2000000.00	1975	2020-06-03	3
1	1975	2020-06-03	2500000.00	1976	2020-06-05	2
1	1976	2020-06-05	2500000.00	1977	2020-06-08	7
1	1977	2020-06-08	2500000.00	1978	2020-06-10	5
1	1978	2020-06-10	2500000.00	1979	2020-06-12	3
1	1979	2020-06-12	2500000.00	1980	2020-06-15	2
1	1980	2020-06-15	2500000.00	1981	2020-06-17	3
1	1981	2020-06-17	2500000.00	1982	2020-06-19	5
1	1982	2020-06-19	2500000.00	1983	2020-06-22	1
1	1983	2020-06-22	2500000.00	1984	2020-06-24	3
1	1984	2020-06-24	4500000.00	1985	2020-06-26	0
1	1985	2020-06-26	2500000.00	1986	2020-06-29	2
1	1986	2020-06-29	2500000.00	1987	2020-07-01	9
1	1987	2020-07-01	2500000.00	1988	2020-07-03	3
1	1988	2020-07-03	2500000.00	1989	2020-07-06	8
1	1989	2020-07-06	2500000.00	1990	2020-07-08	2
1	1990	2020-07-08	5500000.00	1991	2020-07-10	0
1	1991	2020-07-10	2500000.00	1992	2020-07-13	5
1	1992	2020-07-13	2500000.00	1993	2020-07-15	3
1	1993	2020-07-15	6000000.00	1994	2020-07-17	0
1	1994	2020-07-17	2500000.00	1995	2020-07-20	6
1	1995	2020-07-20	2500000.00	1996	2020-07-22	6
1	1996	2020-07-22	2500000.00	1997	2020-07-24	4
1	1997	2020-07-24	2500000.00	1998	2020-07-27	1
1	1998	2020-07-27	2500000.00	1999	2020-07-29	1
1	1999	2020-07-29	2500000.00	2000	2020-07-31	3
1	2000	2020-07-31	2500000.00	2001	2020-08-03	2
1	2001	2020-08-03	1500000.00	2002	2020-08-04	1
1	2002	2020-08-04	1200000.00	2003	2020-08-05	1
1	2003	2020-08-05	1200000.00	2004	2020-08-06	1
1	2004	2020-08-06	1500000.00	2005	2020-08-07	1
1	2005	2020-08-07	1200000.00	2006	2020-08-08	1
1	2006	2020-08-08	1500000.00	2007	2020-08-10	1
1	2007	2020-08-10	3000000.00	2008	2020-08-11	0
1	2008	2020-08-11	5000000.00	2009	2020-08-12	0
1	2009	2020-08-12	3500000.00	2010	2020-08-13	4
1	2010	2020-08-13	1500000.00	2011	2020-08-14	1
1	2011	2020-08-14	1200000.00	2012	2020-08-15	4
1	2012	2020-08-15	2500000.00	2013	2020-08-17	0
1	2013	2020-08-17	1500000.00	2014	2020-08-18	5
1	2014	2020-08-18	3500000.00	2015	2020-08-19	0
1	2015	2020-08-19	1200000.00	2016	2020-08-20	7
1	2016	2020-08-20	1500000.00	2017	2020-08-21	1
1	2017	2020-08-21	1200000.00	2018	2020-08-22	1
1	2018	2020-08-22	2900000.00	2019	2020-08-24	0
1	2019	2020-08-24	3500000.00	2020	2020-08-25	2
1	2020	2020-08-25	1500000.00	2021	2020-08-26	4
1	2021	2020-08-26	3000000.00	2022	2020-08-27	0
1	2022	2020-08-27	1500000.00	2023	2020-08-28	1
1	2023	2020-08-28	1200000.00	2024	2020-08-29	2
1	2024	2020-08-29	1500000.00	2025	2020-08-31	1
1	2025	2020-08-31	1200000.00	2026	2020-09-01	6
1	2026	2020-09-01	3400000.00	2027	2020-09-02	0
1	2027	2020-09-02	1200000.00	2028	2020-09-03	2
1	2028	2020-09-03	1500000.00	2029	2020-09-04	1
1	2029	2020-09-04	120000000.00	2030	2020-09-12	0
1	2030	2020-09-12	1500000.00	2031	2020-09-14	50
1	2031	2020-09-14	1200000.00	2032	2020-09-15	2
1	2032	2020-09-15	1500000.00	2033	2020-09-16	8
1	2033	2020-09-16	1200000.00	2034	2020-09-17	2
1	2034	2020-09-17	1500000.00	2035	2020-09-18	103
1	2035	2020-09-18	1200000.00	2036	2020-09-19	5
1	2036	2020-09-19	1500000.00	2037	2020-09-21	2
1	2037	2020-09-21	1200000.00	2038	2020-09-22	1
1	2038	2020-09-22	1500000.00	2039	2020-09-23	1
1	2039	2020-09-23	3500000.00	2040	2020-09-24	2
1	2040	2020-09-24	1500000.00	2041	2020-09-25	1
1	2041	2020-09-25	1200000.00	2042	2020-09-26	4
1	2042	2020-09-26	1500000.00	2043	2020-09-28	1
1	2043	2020-09-28	1200000.00	2044	2020-09-29	4
1	2044	2020-09-29	3500000.00	2045	2020-09-30	0
1	2045	2020-09-30	1200000.00	2046	2020-10-01	1
1	2046	2020-10-01	1500000.00	2047	2020-10-02	2
1	2047	2020-10-02	1200000.00	2048	2020-10-03	2
1	2048	2020-10-03	1500000.00	2049	2020-10-05	1
1	2049	2020-10-05	3500000.00	2050	2020-10-06	1
1	2050	2020-10-06	1500000.00	2051	2020-10-07	1
1	2051	2020-10-07	1200000.00	2052	2020-10-08	1
1	2052	2020-10-08	1500000.00	2053	2020-10-09	2
1	2053	2020-10-09	1200000.00	2054	2020-10-10	1
1	2054	2020-10-10	1500000.00	2055	2020-10-13	4
1	2055	2020-10-13	1500000.00	2056	2020-10-14	3
1	2056	2020-10-14	3400000.00	2057	2020-10-15	0
1	2057	2020-10-15	1500000.00	2058	2020-10-16	4
1	2058	2020-10-16	1200000.00	2059	2020-10-17	1
1	2059	2020-10-17	3700000.00	2060	2020-10-19	1
1	2060	2020-10-19	1200000.00	2061	2020-10-20	4
1	2061	2020-10-20	1500000.00	2062	2020-10-21	2
1	2062	2020-10-21	1200000.00	2063	2020-10-22	1
1	2063	2020-10-22	1500000.00	2064	2020-10-23	1
1	2064	2020-10-23	1200000.00	2065	2020-10-24	1
1	2065	2020-10-24	1500000.00	2066	2020-10-26	5
1	2066	2020-10-26	3000000.00	2067	2020-10-27	0
1	2067	2020-10-27	1500000.00	2068	2020-10-28	3
1	2068	2020-10-28	3000000.00	2069	2020-10-29	0
1	2069	2020-10-29	3500000.00	2070	2020-10-30	5
1	2070	2020-10-30	1200000.00	2071	2020-10-31	4
1	2071	2020-10-31	1500000.00	2072	2020-11-03	1
1	2072	2020-11-03	4000000.00	2073	2020-11-04	0
1	2073	2020-11-04	1200000.00	2074	2020-11-05	5
1	2074	2020-11-05	1500000.00	2075	2020-11-06	2
1	2075	2020-11-06	1500000.00	2076	2020-11-07	7
1	2076	2020-11-07	1500000.00	2077	2020-11-09	3
1	2077	2020-11-09	1500000.00	2078	2020-11-10	3
1	2078	2020-11-10	3500000.00	2079	2020-11-11	0
1	2079	2020-11-11	7500000.00	2080	2020-11-12	0
1	2080	2020-11-12	1500000.00	2081	2020-11-13	2
1	2081	2020-11-13	1500000.00	2082	2020-11-14	1
1	2082	2020-11-14	4000000.00	2083	2020-11-16	0
1	2083	2020-11-16	1500000.00	2084	2020-11-17	3
1	2084	2020-11-17	1500000.00	2085	2020-11-18	1
1	2085	2020-11-18	3500000.00	2086	2020-11-19	0
1	2086	2020-11-19	5000000.00	2087	2020-11-20	0
1	2087	2020-11-20	1500000.00	2088	2020-11-21	1
1	2088	2020-11-21	1500000.00	2089	2020-11-23	1
1	2089	2020-11-23	4000000.00	2090	2020-11-24	2
1	2090	2020-11-24	1500000.00	2091	2020-11-25	1
1	2091	2020-11-25	3500000.00	2092	2020-11-26	0
1	2092	2020-11-26	1500000.00	2093	2020-11-27	4
1	2093	2020-11-27	1500000.00	2094	2020-11-28	1
1	2094	2020-11-28	1500000.00	2095	2020-11-30	4
1	2095	2020-11-30	1500000.00	2096	2020-12-01	1
1	2096	2020-12-01	3500000.00	2097	2020-12-02	0
1	2097	2020-12-02	1500000.00	2098	2020-12-03	2
1	2098	2020-12-03	3500000.00	2099	2020-12-04	0
1	2099	2020-12-04	3700000.00	2100	2020-12-05	2
1	2100	2020-12-05	1500000.00	2101	2020-12-07	1
1	2101	2020-12-07	3500000.00	2102	2020-12-08	0
1	2102	2020-12-08	1500000.00	2103	2020-12-09	2
1	2103	2020-12-09	1500000.00	2104	2020-12-10	1
1	2104	2020-12-10	1500000.00	2105	2020-12-11	7
1	2105	2020-12-11	1500000.00	2106	2020-12-12	3
1	2106	2020-12-12	1500000.00	2107	2020-12-14	1
1	2107	2020-12-14	1500000.00	2108	2020-12-15	4
1	2108	2020-12-15	3500000.00	2109	2020-12-16	0
1	2109	2020-12-16	3800000.00	2110	2020-12-17	4
1	2110	2020-12-17	7000000.00	2111	2020-12-18	0
1	2111	2020-12-18	1500000.00	2112	2020-12-19	3
1	2112	2020-12-19	3200000.00	2113	2020-12-21	0
1	2113	2020-12-21	1500000.00	2114	2020-12-22	5
1	2114	2020-12-22	3500000.00	2115	2020-12-23	0
1	2115	2020-12-23	800000.00	2116	2020-12-24	1
1	2116	2020-12-24	1200000.00	2117	2020-12-26	2
1	2117	2020-12-26	1500000.00	2118	2020-12-28	1
1	2118	2020-12-28	1500000.00	2119	2020-12-29	3
1	2119	2020-12-29	7000000.00	2120	2020-12-30	0
1	2120	2020-12-30	800000.00	2121	2020-12-31	2
1	2121	2020-12-31	2500000.00	2122	2021-01-02	0
1	2122	2021-01-02	1500000.00	2123	2021-01-04	1
1	2123	2021-01-04	3700000.00	2124	2021-01-05	0
1	2124	2021-01-05	1500000.00	2125	2021-01-06	3
1	2125	2021-01-06	1500000.00	2126	2021-01-07	1
1	2126	2021-01-07	1500000.00	2127	2021-01-08	2
1	2127	2021-01-08	1500000.00	2128	2021-01-09	2
1	2128	2021-01-09	1500000.00	2129	2021-01-11	2
1	2129	2021-01-11	4000000.00	2130	2021-01-12	1
1	2130	2021-01-12	1500000.00	2131	2021-01-13	1
1	2131	2021-01-13	3700000.00	2132	2021-01-14	0
1	2132	2021-01-14	1500000.00	2133	2021-01-15	2
1	2133	2021-01-15	4000000.00	2134	2021-01-16	0
1	2134	2021-01-16	1500000.00	2135	2021-01-18	5
1	2135	2021-01-18	1500000.00	2136	2021-01-19	2
1	2136	2021-01-19	3500000.00	2137	2021-01-20	0
1	2137	2021-01-20	1500000.00	2138	2021-01-21	1
1	2138	2021-01-21	1500000.00	2139	2021-01-22	1
1	2139	2021-01-22	4000000.00	2140	2021-01-23	3
1	2140	2021-01-23	7000000.00	2141	2021-01-25	0
1	2141	2021-01-25	1500000.00	2142	2021-01-26	4
1	2142	2021-01-26	1500000.00	2143	2021-01-27	2
1	2143	2021-01-27	3500000.00	2144	2021-01-28	0
1	2144	2021-01-28	1500000.00	2145	2021-01-29	1
1	2145	2021-01-29	1500000.00	2146	2021-01-30	1
1	2146	2021-01-30	1500000.00	2147	2021-02-01	4
1	2147	2021-02-01	1500000.00	2148	2021-02-02	1
1	2148	2021-02-02	3500000.00	2149	2021-02-03	0
1	2149	2021-02-03	4000000.00	2150	2021-02-04	2
1	2150	2021-02-04	1500000.00	2151	2021-02-05	1
1	2151	2021-02-05	1500000.00	2152	2021-02-06	1
1	2152	2021-02-06	1500000.00	2153	2021-02-08	1
1	2153	2021-02-08	1500000.00	2154	2021-02-09	1
1	2154	2021-02-09	1500000.00	2155	2021-02-10	2
1	2155	2021-02-10	1500000.00	2156	2021-02-11	2
1	2156	2021-02-11	1500000.00	2157	2021-02-12	2
1	2157	2021-02-12	1500000.00	2158	2021-02-13	1
1	2158	2021-02-13	1500000.00	2159	2021-02-17	1
1	2159	2021-02-17	7000000.00	2160	2021-02-18	0
1	2160	2021-02-18	1500000.00	2161	2021-02-19	6
1	2161	2021-02-19	1500000.00	2162	2021-02-20	1
1	2162	2021-02-20	1500000.00	2163	2021-02-22	2
1	2163	2021-02-22	1500000.00	2164	2021-02-23	4
1	2164	2021-02-23	1500000.00	2165	2021-02-24	2
1	2165	2021-02-24	1500000.00	2166	2021-02-25	2
1	2166	2021-02-25	1500000.00	2167	2021-02-26	2
1	2167	2021-02-26	1500000.00	2168	2021-02-27	1
1	2168	2021-02-27	1500000.00	2169	2021-03-01	1
1	2169	2021-03-01	3500000.00	2170	2021-03-02	2
1	2170	2021-03-02	7000000.00	2171	2021-03-03	0
1	2171	2021-03-03	1500000.00	2172	2021-03-04	7
1	2172	2021-03-04	1500000.00	2173	2021-03-05	3
1	2173	2021-03-05	3500000.00	2174	2021-03-06	0
1	2174	2021-03-06	1500000.00	2175	2021-03-08	1
1	2175	2021-03-08	1500000.00	2176	2021-03-09	1
1	2176	2021-03-09	1500000.00	2177	2021-03-10	1
1	2177	2021-03-10	1500000.00	2178	2021-03-11	11
1	2178	2021-03-11	1500000.00	2179	2021-03-12	2
1	2179	2021-03-12	4000000.00	2180	2021-03-13	1
1	2180	2021-03-13	1500000.00	2181	2021-03-15	2
1	2181	2021-03-15	1500000.00	2182	2021-03-16	2
1	2182	2021-03-16	1500000.00	2183	2021-03-17	2
1	2183	2021-03-17	1500000.00	2184	2021-03-18	1
1	2184	2021-03-18	1500000.00	2185	2021-03-19	3
1	2185	2021-03-19	1500000.00	2186	2021-03-20	3
1	2186	2021-03-20	3000000.00	2187	2021-03-22	0
1	2187	2021-03-22	1500000.00	2188	2021-03-23	2
1	2188	2021-03-23	1500000.00	2189	2021-03-24	1
1	2189	2021-03-24	4000000.00	2190	2021-03-25	2
1	2190	2021-03-25	1500000.00	2191	2021-03-26	2
1	2191	2021-03-26	3300000.00	2192	2021-03-27	0
1	2192	2021-03-27	4900000.00	2193	2021-03-29	0
1	2193	2021-03-29	1500000.00	2194	2021-03-30	3
1	2194	2021-03-30	1500000.00	2195	2021-03-31	1
1	2195	2021-03-31	1500000.00	2196	2021-04-01	2
1	2196	2021-04-01	1500000.00	2197	2021-04-03	2
1	2197	2021-04-03	3000000.00	2198	2021-04-05	0
1	2198	2021-04-05	1500000.00	2199	2021-04-06	1
1	2199	2021-04-06	4000000.00	2200	2021-04-07	3
1	2200	2021-04-07	1500000.00	2201	2021-04-08	10
1	2201	2021-04-08	3500000.00	2202	2021-04-09	0
1	2202	2021-04-09	1500000.00	2203	2021-04-10	4
1	2203	2021-04-10	1500000.00	2204	2021-04-12	1
1	2204	2021-04-12	1500000.00	2205	2021-04-13	1
1	2205	2021-04-13	1500000.00	2206	2021-04-14	3
1	2206	2021-04-14	1500000.00	2207	2021-04-15	2
1	2207	2021-04-15	1500000.00	2208	2021-04-16	1
1	2208	2021-04-16	1500000.00	2209	2021-04-17	4
1	2209	2021-04-17	7000000.00	2210	2021-04-19	0
1	2210	2021-04-19	1500000.00	2211	2021-04-20	4
1	2211	2021-04-20	1500000.00	2212	2021-04-22	12
1	2212	2021-04-22	1500000.00	2213	2021-04-23	2
1	2213	2021-04-23	4000000.00	2214	2021-04-24	0
1	2214	2021-04-24	7000000.00	2215	2021-04-26	0
1	2215	2021-04-26	1500000.00	2216	2021-04-27	11
1	2216	2021-04-27	1500000.00	2217	2021-04-28	2
1	2217	2021-04-28	1500000.00	2218	2021-04-29	1
1	2218	2021-04-29	3500000.00	2219	2021-04-30	0
1	2219	2021-04-30	4000000.00	2220	2021-05-03	3
1	2220	2021-05-03	1500000.00	2221	2021-05-04	3
1	2221	2021-05-04	1500000.00	2222	2021-05-05	1
1	2222	2021-05-05	1500000.00	2223	2021-05-06	1
1	2223	2021-05-06	3500000.00	2224	2021-05-07	0
1	2224	2021-05-07	1500000.00	2225	2021-05-08	3
1	2225	2021-05-08	3000000.00	2226	2021-05-10	0
1	2226	2021-05-10	1500000.00	2227	2021-05-11	4
1	2227	2021-05-11	3500000.00	2228	2021-05-12	0
1	2228	2021-05-12	1500000.00	2229	2021-05-13	2
1	2229	2021-05-13	4000000.00	2230	2021-05-14	1
1	2230	2021-05-14	1500000.00	2231	2021-05-15	2
1	2231	2021-05-15	1500000.00	2232	2021-05-17	2
1	2232	2021-05-17	1500000.00	2233	2021-05-18	5
1	2233	2021-05-18	3500000.00	2234	2021-05-19	0
1	2234	2021-05-19	1500000.00	2235	2021-05-20	3
1	2235	2021-05-20	1500000.00	2236	2021-05-21	2
1	2236	2021-05-21	1500000.00	2237	2021-05-22	1
1	2237	2021-05-22	1500000.00	2238	2021-05-24	2
1	2238	2021-05-24	1500000.00	2239	2021-05-25	2
1	2239	2021-05-25	4000000.00	2240	2021-05-26	3
1	2240	2021-05-26	1500000.00	2241	2021-05-27	2
1	2241	2021-05-27	3000000.00	2242	2021-05-28	0
1	2242	2021-05-28	1500000.00	2243	2021-05-29	1
1	2243	2021-05-29	3000000.00	2244	2021-05-31	0
1	2244	2021-05-31	1500000.00	2245	2021-06-01	1
1	2245	2021-06-01	1500000.00	2246	2021-06-02	2
1	2246	2021-06-02	1500000.00	2247	2021-06-04	1
1	2247	2021-06-04	1500000.00	2248	2021-06-05	3
1	2248	2021-06-05	1500000.00	2249	2021-06-07	2
1	2249	2021-06-07	4000000.00	2250	2021-06-08	1
1	2250	2021-06-08	1500000.00	2251	2021-06-09	2
1	2251	2021-06-09	1500000.00	2252	2021-06-10	4
1	2252	2021-06-10	3500000.00	2253	2021-06-11	0
1	2253	2021-06-11	1500000.00	2254	2021-06-12	4
1	2254	2021-06-12	1500000.00	2255	2021-06-14	3
1	2255	2021-06-14	3500000.00	2256	2021-06-15	0
1	2256	2021-06-15	1500000.00	2257	2021-06-16	3
1	2257	2021-06-16	1500000.00	2258	2021-06-17	3
1	2258	2021-06-17	1500000.00	2259	2021-06-18	4
1	2259	2021-06-18	7000000.00	2260	2021-06-19	0
1	2260	2021-06-19	1500000.00	2261	2021-06-21	5
1	2261	2021-06-21	1500000.00	2262	2021-06-22	2
1	2262	2021-06-22	1500000.00	2263	2021-06-23	1
1	2263	2021-06-23	1500000.00	2264	2021-06-24	5
1	2264	2021-06-24	1500000.00	2265	2021-06-25	2
1	2265	2021-06-25	1500000.00	2266	2021-06-26	2
1	2266	2021-06-26	1500000.00	2267	2021-06-28	3
1	2267	2021-06-28	1500000.00	2268	2021-06-29	4
1	2268	2021-06-29	3000000.00	2269	2021-06-30	0
1	2269	2021-06-30	4000000.00	2270	2021-07-01	2
1	2270	2021-07-01	1500000.00	2271	2021-07-02	3
1	2271	2021-07-02	1500000.00	2272	2021-07-03	3
1	2272	2021-07-03	1500000.00	2273	2021-07-05	7
1	2273	2021-07-05	1500000.00	2274	2021-07-06	2
1	2274	2021-07-06	1500000.00	2275	2021-07-07	2
1	2275	2021-07-07	3500000.00	2276	2021-07-08	0
1	2276	2021-07-08	1500000.00	2277	2021-07-09	2
1	2277	2021-07-09	3500000.00	2278	2021-07-10	0
1	2278	2021-07-10	1500000.00	2279	2021-07-12	3
1	2279	2021-07-12	4000000.00	2280	2021-07-13	3
1	2280	2021-07-13	1500000.00	2281	2021-07-14	1
1	2281	2021-07-14	1500000.00	2282	2021-07-15	3
1	2282	2021-07-15	1500000.00	2283	2021-07-16	2
1	2283	2021-07-16	1500000.00	2284	2021-07-17	1
1	2284	2021-07-17	1500000.00	2285	2021-07-19	4
1	2285	2021-07-19	1500000.00	2286	2021-07-20	1
1	2286	2021-07-20	1500000.00	2287	2021-07-21	1
1	2287	2021-07-21	3500000.00	2288	2021-07-22	0
1	2288	2021-07-22	1500000.00	2289	2021-07-23	3
1	2289	2021-07-23	4000000.00	2290	2021-07-24	1
1	2290	2021-07-24	1500000.00	2291	2021-07-26	3
1	2291	2021-07-26	1500000.00	2292	2021-07-27	11
1	2292	2021-07-27	1500000.00	2293	2021-07-28	2
1	2293	2021-07-28	1500000.00	2294	2021-07-29	2
1	2294	2021-07-29	1500000.00	2295	2021-07-30	1
1	2295	2021-07-30	1500000.00	2296	2021-07-31	1
1	2296	2021-07-31	1500000.00	2297	2021-08-02	1
1	2297	2021-08-02	1500000.00	2298	2021-08-03	4
1	2298	2021-08-03	1500000.00	2299	2021-08-04	1
1	2299	2021-08-04	4000000.00	2300	2021-08-05	6
1	2300	2021-08-05	6000000.00	2301	2021-08-06	0
1	2301	2021-08-06	1500000.00	2302	2021-08-07	2
1	2302	2021-08-07	1500000.00	2303	2021-08-09	1
1	2303	2021-08-09	1500000.00	2304	2021-08-10	9
1	2304	2021-08-10	1500000.00	2305	2021-08-11	1
1	2305	2021-08-11	3500000.00	2306	2021-08-12	0
1	2306	2021-08-12	1500000.00	2307	2021-08-13	1
1	2307	2021-08-13	3500000.00	2308	2021-08-14	0
1	2308	2021-08-14	1500000.00	2309	2021-08-16	1
1	2309	2021-08-16	4000000.00	2310	2021-08-17	8
1	2310	2021-08-17	1500000.00	2311	2021-08-18	6
1	2311	2021-08-18	3000000.00	2312	2021-08-19	0
1	2312	2021-08-19	1500000.00	2313	2021-08-20	2
1	2313	2021-08-20	3000000.00	2314	2021-08-21	0
1	2314	2021-08-21	1500000.00	2315	2021-08-23	5
1	2315	2021-08-23	3500000.00	2316	2021-08-24	0
1	2316	2021-08-24	1500000.00	2317	2021-08-25	3
1	2317	2021-08-25	3500000.00	2318	2021-08-26	0
1	2318	2021-08-26	6500000.00	2319	2021-08-27	0
1	2319	2021-08-27	150000000.00	2320	2021-09-11	1
1	2320	2021-09-11	1500000.00	2321	2021-09-13	57
1	2321	2021-09-13	4000000.00	2322	2021-09-14	0
1	2322	2021-09-14	7800000.00	2323	2021-09-15	0
1	2323	2021-09-15	1500000.00	2324	2021-09-16	5
1	2324	2021-09-16	1500000.00	2325	2021-09-17	1
1	2325	2021-09-17	1500000.00	2326	2021-09-18	1
1	2326	2021-09-18	1500000.00	2327	2021-09-20	1
1	2327	2021-09-20	1500000.00	2328	2021-09-21	1
1	2328	2021-09-21	1500000.00	2329	2021-09-22	2
1	2329	2021-09-22	4500000.00	2330	2021-09-23	2
1	2330	2021-09-23	1500000.00	2331	2021-09-24	4
1	2331	2021-09-24	1500000.00	2332	2021-09-25	3
1	2332	2021-09-25	3500000.00	2333	2021-09-27	0
1	2333	2021-09-27	1500000.00	2334	2021-09-28	2
1	2334	2021-09-28	1500000.00	2335	2021-09-29	2
1	2335	2021-09-29	3600000.00	2336	2021-09-30	0
1	2336	2021-09-30	1600000.00	2337	2021-10-01	1
1	2337	2021-10-01	1600000.00	2338	2021-10-02	3
1	2338	2021-10-02	1500000.00	2339	2021-10-04	1
1	2339	2021-10-04	4000000.00	2340	2021-10-05	2
1	2340	2021-10-05	1500000.00	2341	2021-10-06	6
1	2341	2021-10-06	1500000.00	2342	2021-10-07	3
1	2342	2021-10-07	3500000.00	2343	2021-10-08	0
1	2343	2021-10-08	1500000.00	2344	2021-10-09	1
1	2344	2021-10-09	1500000.00	2345	2021-10-11	2
1	2345	2021-10-11	1500000.00	2346	2021-10-13	2
1	2346	2021-10-13	1500000.00	2347	2021-10-14	2
1	2347	2021-10-14	1500000.00	2348	2021-10-15	11
1	2348	2021-10-15	1500000.00	2349	2021-10-16	5
1	2349	2021-10-16	6100000.00	2350	2021-10-18	0
1	2350	2021-10-18	1500000.00	2351	2021-10-19	1
1	2351	2021-10-19	1500000.00	2352	2021-10-20	1
1	2352	2021-10-20	1500000.00	2353	2021-10-21	1
1	2353	2021-10-21	1500000.00	2354	2021-10-22	2
1	2354	2021-10-22	1500000.00	2355	2021-10-23	4
1	2355	2021-10-23	1500000.00	2356	2021-10-25	1
1	2356	2021-10-25	4000000.00	2357	2021-10-26	0
1	2357	2021-10-26	1500000.00	2358	2021-10-27	3
1	2358	2021-10-27	1500000.00	2359	2021-10-28	1
1	2359	2021-10-28	4000000.00	2360	2021-10-29	1
1	2360	2021-10-29	1500000.00	2361	2021-10-30	1
1	2361	2021-10-30	1500000.00	2362	2021-11-01	2
1	2362	2021-11-01	4000000.00	2363	2021-11-03	0
1	2363	2021-11-03	1500000.00	2364	2021-11-04	1
1	2364	2021-11-04	3500000.00	2365	2021-11-05	0
1	2365	2021-11-05	7500000.00	2366	2021-11-06	0
1	2366	2021-11-06	1500000.00	2367	2021-11-08	19
1	2367	2021-11-08	1500000.00	2368	2021-11-09	10
1	2368	2021-11-09	1500000.00	2369	2021-11-10	2
1	2369	2021-11-10	5200000.00	2370	2021-11-11	1
1	2370	2021-11-11	1500000.00	2371	2021-11-12	1
1	2371	2021-11-12	4000000.00	2372	2021-11-13	0
1	2372	2021-11-13	6500000.00	2373	2021-11-16	0
1	2373	2021-11-16	1500000.00	2374	2021-11-17	1
1	2374	2021-11-17	1500000.00	2375	2021-11-18	1
1	2375	2021-11-18	1500000.00	2376	2021-11-19	1
1	2376	2021-11-19	1500000.00	2377	2021-11-20	2
1	2377	2021-11-20	1500000.00	2378	2021-11-22	3
1	2378	2021-11-22	1500000.00	2379	2021-11-23	1
1	2379	2021-11-23	4500000.00	2380	2021-11-24	3
1	2380	2021-11-24	1500000.00	2381	2021-11-25	1
1	2381	2021-11-25	1500000.00	2382	2021-11-26	4
1	2382	2021-11-26	3500000.00	2383	2021-11-27	0
1	2383	2021-11-27	1500000.00	2384	2021-11-29	3
1	2384	2021-11-29	1500000.00	2385	2021-11-30	38
1	2385	2021-11-30	3500000.00	2386	2021-12-01	0
1	2386	2021-12-01	1500000.00	2387	2021-12-02	6
1	2387	2021-12-02	1500000.00	2388	2021-12-03	3
1	2388	2021-12-03	1500000.00	2389	2021-12-04	4
1	2389	2021-12-04	6000000.00	2390	2021-12-06	0
1	2390	2021-12-06	1500000.00	2391	2021-12-07	8
1	2391	2021-12-07	1500000.00	2392	2021-12-08	1
1	2392	2021-12-08	3600000.00	2393	2021-12-09	0
1	2393	2021-12-09	6000000.00	2394	2021-12-10	0
1	2394	2021-12-10	1500000.00	2395	2021-12-11	4
1	2395	2021-12-11	1500000.00	2396	2021-12-13	2
1	2396	2021-12-13	1500000.00	2397	2021-12-14	4
1	2397	2021-12-14	1500000.00	2398	2021-12-15	1
1	2398	2021-12-15	3500000.00	2399	2021-12-16	0
1	2399	2021-12-16	8500000.00	2400	2021-12-17	0
1	2400	2021-12-17	1500000.00	2401	2021-12-18	3
1	2401	2021-12-18	1500000.00	2402	2021-12-20	4
1	2402	2021-12-20	1500000.00	2403	2021-12-21	3
1	2403	2021-12-21	1500000.00	2404	2021-12-22	1
1	2404	2021-12-22	1500000.00	2405	2021-12-23	1
1	2405	2021-12-23	1500000.00	2406	2021-12-24	1
1	2406	2021-12-24	1500000.00	2407	2021-12-27	3
1	2407	2021-12-27	1500000.00	2408	2021-12-28	1
1	2408	2021-12-28	1500000.00	2409	2021-12-29	4
1	2409	2021-12-29	4000000.00	2410	2021-12-30	3
1	2410	2021-12-30	1200000.00	2411	2021-12-31	3
1	2411	2021-12-31	1500000.00	2412	2022-01-03	7
1	2412	2022-01-03	1500000.00	2413	2022-01-04	3
1	2413	2022-01-04	1500000.00	2414	2022-01-05	2
1	2414	2022-01-05	1500000.00	2415	2022-01-06	4
1	2415	2022-01-06	4000000.00	2416	2022-01-07	0
1	2416	2022-01-07	1500000.00	2417	2022-01-08	1
1	2417	2022-01-08	1500000.00	2418	2022-01-10	1
1	2418	2022-01-10	1500000.00	2419	2022-01-11	4
1	2419	2022-01-11	7000000.00	2420	2022-01-12	0
1	2420	2022-01-12	1500000.00	2421	2022-01-13	2
1	2421	2022-01-13	1500000.00	2422	2022-01-14	3
1	2422	2022-01-14	1500000.00	2423	2022-01-15	1
1	2423	2022-01-15	1500000.00	2424	2022-01-17	1
1	2424	2022-01-17	1500000.00	2425	2022-01-18	1
1	2425	2022-01-18	1500000.00	2426	2022-01-19	1
1	2426	2022-01-19	1500000.00	2427	2022-01-20	2
1	2427	2022-01-20	1500000.00	2428	2022-01-21	1
1	2428	2022-01-21	4200000.00	2429	2022-01-22	0
1	2429	2022-01-22	4000000.00	2430	2022-01-24	2
1	2430	2022-01-24	1500000.00	2431	2022-01-25	7
1	2431	2022-01-25	3500000.00	2432	2022-01-26	0
1	2432	2022-01-26	1500000.00	2433	2022-01-27	1
1	2433	2022-01-27	1500000.00	2434	2022-01-28	4
1	2434	2022-01-28	1500000.00	2435	2022-01-29	1
1	2435	2022-01-29	1500000.00	2436	2022-01-31	4
1	2436	2022-01-31	1500000.00	2437	2022-02-01	1
1	2437	2022-02-01	1500000.00	2438	2022-02-02	1
1	2438	2022-02-02	1500000.00	2439	2022-02-03	2
1	2439	2022-02-03	4000000.00	2440	2022-02-04	5
1	2440	2022-02-04	1500000.00	2441	2022-02-05	4
1	2441	2022-02-05	1500000.00	2442	2022-02-07	3
1	2442	2022-02-07	1500000.00	2443	2022-02-08	2
1	2443	2022-02-08	1500000.00	2444	2022-02-09	3
1	2444	2022-02-09	1500000.00	2445	2022-02-10	2
1	2445	2022-02-10	3500000.00	2446	2022-02-11	0
1	2446	2022-02-11	1500000.00	2447	2022-02-12	2
1	2447	2022-02-12	1500000.00	2448	2022-02-14	1
1	2448	2022-02-14	1500000.00	2449	2022-02-15	2
1	2449	2022-02-15	6200000.00	2450	2022-02-16	0
1	2450	2022-02-16	1500000.00	2451	2022-02-17	1
1	2451	2022-02-17	1500000.00	2452	2022-02-18	1
1	2452	2022-02-18	4000000.00	2453	2022-02-19	0
1	2453	2022-02-19	1500000.00	2454	2022-02-21	1
1	2454	2022-02-21	1500000.00	2455	2022-02-22	1
1	2455	2022-02-22	1500000.00	2456	2022-02-23	3
1	2456	2022-02-23	3800000.00	2457	2022-02-24	0
1	2457	2022-02-24	1500000.00	2458	2022-02-25	5
1	2458	2022-02-25	1500000.00	2459	2022-02-26	1
1	2459	2022-02-26	4000000.00	2460	2022-03-02	1
1	2460	2022-03-02	1500000.00	2461	2022-03-03	3
1	2461	2022-03-03	1500000.00	2462	2022-03-04	1
1	2462	2022-03-04	1500000.00	2463	2022-03-05	2
1	2463	2022-03-05	1500000.00	2464	2022-03-07	1
1	2464	2022-03-07	1500000.00	2465	2022-03-08	3
1	2465	2022-03-08	1500000.00	2466	2022-03-09	2
1	2466	2022-03-09	1500000.00	2467	2022-03-10	18
1	2467	2022-03-10	1500000.00	2468	2022-03-11	3
1	2468	2022-03-11	1500000.00	2469	2022-03-12	1
1	2469	2022-03-12	4000000.00	2470	2022-03-14	2
1	2470	2022-03-14	1500000.00	2471	2022-03-15	4
1	2471	2022-03-15	3500000.00	2472	2022-03-16	0
1	2472	2022-03-16	1500000.00	2473	2022-03-17	2
1	2473	2022-03-17	1500000.00	2474	2022-03-18	1
1	2474	2022-03-18	1500000.00	2475	2022-03-19	8
1	2475	2022-03-19	1500000.00	2476	2022-03-21	2
1	2476	2022-03-21	4000000.00	2477	2022-03-22	0
1	2477	2022-03-22	1500000.00	2478	2022-03-23	4
1	2478	2022-03-23	1500000.00	2479	2022-03-24	1
1	2479	2022-03-24	4000000.00	2480	2022-03-25	1
1	2480	2022-03-25	1500000.00	2481	2022-03-26	3
1	2481	2022-03-26	1500000.00	2482	2022-03-28	1
1	2482	2022-03-28	3500000.00	2483	2022-03-29	0
1	2483	2022-03-29	1500000.00	2484	2022-03-30	7
1	2484	2022-03-30	1500000.00	2485	2022-03-31	1
1	2485	2022-03-31	1500000.00	2486	2022-04-01	2
1	2486	2022-04-01	1500000.00	2487	2022-04-02	4
1	2487	2022-04-02	1500000.00	2488	2022-04-04	2
1	2488	2022-04-04	4000000.00	2489	2022-04-05	0
1	2489	2022-04-05	4000000.00	2490	2022-04-06	3
1	2490	2022-04-06	1500000.00	2491	2022-04-07	1
1	2491	2022-04-07	4000000.00	2492	2022-04-08	0
1	2492	2022-04-08	1500000.00	2493	2022-04-09	1
1	2493	2022-04-09	1500000.00	2494	2022-04-11	1
1	2494	2022-04-11	1500000.00	2495	2022-04-12	1
1	2495	2022-04-12	3600000.00	2496	2022-04-13	0
1	2496	2022-04-13	1500000.00	2497	2022-04-14	3
1	2497	2022-04-14	1500000.00	2498	2022-04-16	2
1	2498	2022-04-16	1500000.00	2499	2022-04-18	2
1	2499	2022-04-18	4000000.00	2500	2022-04-19	2
1	2500	2022-04-19	1500000.00	2501	2022-04-20	2
1	2501	2022-04-20	1500000.00	2502	2022-04-22	1
1	2502	2022-04-22	1500000.00	2503	2022-04-23	3
1	2503	2022-04-23	1500000.00	2504	2022-04-25	2
1	2504	2022-04-25	1500000.00	2505	2022-04-26	1
1	2505	2022-04-26	1500000.00	2506	2022-04-27	1
1	2506	2022-04-27	1500000.00	2507	2022-04-28	2
1	2507	2022-04-28	1500000.00	2508	2022-04-29	1
1	2508	2022-04-29	1500000.00	2509	2022-04-30	3
1	2509	2022-04-30	4000000.00	2510	2022-05-02	1
1	2510	2022-05-02	1500000.00	2511	2022-05-03	2
1	2511	2022-05-03	1500000.00	2512	2022-05-04	3
1	2512	2022-05-04	1500000.00	2513	2022-05-05	2
1	2513	2022-05-05	1500000.00	2514	2022-05-06	2
1	2514	2022-05-06	1500000.00	2515	2022-05-07	2
1	2515	2022-05-07	1500000.00	2516	2022-05-09	1
1	2516	2022-05-09	1500000.00	2517	2022-05-10	2
1	2517	2022-05-10	1500000.00	2518	2022-05-11	2
1	2518	2022-05-11	1500000.00	2519	2022-05-12	1
1	2519	2022-05-12	4500000.00	2520	2022-05-13	1
1	2520	2022-05-13	1500000.00	2521	2022-05-14	3
1	2521	2022-05-14	1500000.00	2522	2022-05-16	4
1	2522	2022-05-16	1500000.00	2523	2022-05-17	4
1	2523	2022-05-17	1500000.00	2524	2022-05-18	1
1	2524	2022-05-18	1500000.00	2525	2022-05-19	1
1	2525	2022-05-19	1500000.00	2526	2022-05-20	2
1	2526	2022-05-20	1500000.00	2527	2022-05-21	2
1	2527	2022-05-21	1500000.00	2528	2022-05-23	5
1	2528	2022-05-23	1500000.00	2529	2022-05-24	4
1	2529	2022-05-24	5000000.00	2530	2022-05-25	2
1	2530	2022-05-25	9000000.00	2531	2022-05-26	0
1	2531	2022-05-26	1500000.00	2532	2022-05-27	3
1	2532	2022-05-27	1500000.00	2533	2022-05-28	1
1	2533	2022-05-28	4000000.00	2534	2022-05-30	0
1	2534	2022-05-30	1500000.00	2535	2022-05-31	5
1	2535	2022-05-31	3600000.00	2536	2022-06-01	0
1	2536	2022-06-01	1500000.00	2537	2022-06-02	4
1	2537	2022-06-02	1500000.00	2538	2022-06-03	3
1	2538	2022-06-03	1500000.00	2539	2022-06-04	1
1	2539	2022-06-04	5000000.00	2540	2022-06-06	1
1	2540	2022-06-06	1500000.00	2541	2022-06-07	3
1	2541	2022-06-07	1500000.00	2542	2022-06-08	1
1	2542	2022-06-08	1500000.00	2543	2022-06-09	3
1	2543	2022-06-09	1500000.00	2544	2022-06-10	4
1	2544	2022-06-10	1500000.00	2545	2022-06-11	4
1	2545	2022-06-11	1500000.00	2546	2022-06-13	1
1	2546	2022-06-13	1500000.00	2547	2022-06-14	2
1	2547	2022-06-14	4000000.00	2548	2022-06-15	0
1	2548	2022-06-15	1500000.00	2549	2022-06-17	1
1	2549	2022-06-17	5000000.00	2550	2022-06-18	1
1	2550	2022-06-18	1500000.00	2551	2022-06-20	3
1	2551	2022-06-20	1500000.00	2552	2022-06-21	2
1	2552	2022-06-21	1500000.00	2553	2022-06-22	1
1	2553	2022-06-22	1500000.00	2554	2022-06-23	7
1	2554	2022-06-23	1500000.00	2555	2022-06-24	2
1	2555	2022-06-24	1500000.00	2556	2022-06-25	5
1	2556	2022-06-25	1500000.00	2557	2022-06-27	1
1	2557	2022-06-27	4000000.00	2558	2022-06-28	0
1	2558	2022-06-28	1500000.00	2559	2022-06-29	1
1	2559	2022-06-29	5000000.00	2560	2022-06-30	2
1	2560	2022-06-30	1500000.00	2561	2022-07-01	5
1	2561	2022-07-01	1500000.00	2562	2022-07-02	2
1	2562	2022-07-02	1500000.00	2563	2022-07-04	2
1	2563	2022-07-04	1500000.00	2564	2022-07-05	1
1	2564	2022-07-05	1500000.00	2565	2022-07-06	1
1	2565	2022-07-06	1500000.00	2566	2022-07-07	8
1	2566	2022-07-07	1500000.00	2567	2022-07-08	1
1	2567	2022-07-08	4000000.00	2568	2022-07-09	0
1	2568	2022-07-09	1500000.00	2569	2022-07-11	3
1	2569	2022-07-11	5000000.00	2570	2022-07-12	1
1	2570	2022-07-12	1500000.00	2571	2022-07-13	4
1	2571	2022-07-13	1500000.00	2572	2022-07-14	3
1	2572	2022-07-14	1500000.00	2573	2022-07-15	1
1	2573	2022-07-15	1500000.00	2574	2022-07-16	1
1	2574	2022-07-16	1500000.00	2575	2022-07-18	1
1	2575	2022-07-18	1500000.00	2576	2022-07-19	5
1	2576	2022-07-19	1500000.00	2577	2022-07-20	1
1	2577	2022-07-20	1500000.00	2578	2022-07-21	1
1	2578	2022-07-21	1500000.00	2579	2022-07-22	2
1	2579	2022-07-22	5000000.00	2580	2022-07-23	4
1	2580	2022-07-23	1500000.00	2581	2022-07-25	3
1	2581	2022-07-25	1500000.00	2582	2022-07-26	1
1	2582	2022-07-26	1500000.00	2583	2022-07-27	1
1	2583	2022-07-27	1500000.00	2584	2022-07-28	2
1	2584	2022-07-28	1500000.00	2585	2022-07-29	2
1	2585	2022-07-29	1500000.00	2586	2022-07-30	2
1	2586	2022-07-30	1500000.00	2587	2022-08-01	1
1	2587	2022-08-01	4500000.00	2588	2022-08-02	0
1	2588	2022-08-02	1500000.00	2589	2022-08-03	5
1	2589	2022-08-03	5000000.00	2590	2022-08-04	3
1	2590	2022-08-04	1500000.00	2591	2022-08-05	12
1	2591	2022-08-05	4200000.00	2592	2022-08-06	0
1	2592	2022-08-06	7500000.00	2593	2022-08-08	0
1	2593	2022-08-08	1500000.00	2594	2022-08-09	4
1	2594	2022-08-09	1500000.00	2595	2022-08-10	2
1	2595	2022-08-10	1500000.00	2596	2022-08-11	4
1	2596	2022-08-11	4000000.00	2597	2022-08-12	0
1	2597	2022-08-12	1500000.00	2598	2022-08-13	2
1	2598	2022-08-13	4000000.00	2599	2022-08-15	0
1	2599	2022-08-15	5000000.00	2600	2022-08-16	3
1	2600	2022-08-16	1500000.00	2601	2022-08-17	3
1	2601	2022-08-17	1500000.00	2602	2022-08-18	1
1	2602	2022-08-18	1500000.00	2603	2022-08-19	1
1	2603	2022-08-19	1500000.00	2604	2022-08-20	37
1	2604	2022-08-20	4000000.00	2605	2022-08-22	0
1	2605	2022-08-22	1500000.00	2606	2022-08-23	4
1	2606	2022-08-23	1500000.00	2607	2022-08-24	1
1	2607	2022-08-24	3500000.00	2608	2022-08-25	0
1	2608	2022-08-25	6500000.00	2609	2022-08-26	0
1	2609	2022-08-26	180000000.00	2610	2022-09-10	3
1	2610	2022-09-10	1500000.00	2611	2022-09-12	79
1	2611	2022-09-12	1500000.00	2612	2022-09-13	4
1	2612	2022-09-13	1500000.00	2613	2022-09-14	1
1	2613	2022-09-14	1500000.00	2614	2022-09-15	2
1	2614	2022-09-15	4100000.00	2615	2022-09-16	0
1	2615	2022-09-16	1500000.00	2616	2022-09-17	5
1	2616	2022-09-17	1500000.00	2617	2022-09-19	3
1	2617	2022-09-19	1500000.00	2618	2022-09-20	3
1	2618	2022-09-20	1500000.00	2619	2022-09-21	1
1	2619	2022-09-21	5000000.00	2620	2022-09-22	1
1	2620	2022-09-22	1500000.00	2621	2022-09-23	1
1	2621	2022-09-23	1500000.00	2622	2022-09-24	2
1	2622	2022-09-24	4000000.00	2623	2022-09-26	0
1	2623	2022-09-26	1500000.00	2624	2022-09-27	3
1	2624	2022-09-27	1500000.00	2625	2022-09-28	2
1	2625	2022-09-28	1500000.00	2626	2022-09-29	5
1	2626	2022-09-29	3500000.00	2627	2022-09-30	0
1	2627	2022-09-30	1500000.00	2628	2022-10-01	3
1	2628	2022-10-01	1500000.00	2629	2022-10-03	3
1	2629	2022-10-03	5000000.00	2630	2022-10-04	1
1	2630	2022-10-04	1500000.00	2631	2022-10-05	5
1	2631	2022-10-05	1500000.00	2632	2022-10-06	1
1	2632	2022-10-06	1500000.00	2633	2022-10-07	2
1	2633	2022-10-07	5000000.00	2634	2022-10-08	0
1	2634	2022-10-08	1500000.00	2635	2022-10-10	4
1	2635	2022-10-10	1500000.00	2636	2022-10-11	19
1	2636	2022-10-11	1500000.00	2637	2022-10-13	1
1	2637	2022-10-13	1500000.00	2638	2022-10-14	2
1	2638	2022-10-14	1500000.00	2639	2022-10-15	1
1	2639	2022-10-15	5000000.00	2640	2022-10-17	2
1	2640	2022-10-17	1500000.00	2641	2022-10-18	3
1	2641	2022-10-18	1500000.00	2642	2022-10-19	4
1	2642	2022-10-19	1500000.00	2643	2022-10-20	3
1	2643	2022-10-20	3500000.00	2644	2022-10-21	0
1	2644	2022-10-21	1500000.00	2645	2022-10-22	2
1	2645	2022-10-22	1500000.00	2646	2022-10-24	1
1	2646	2022-10-24	1500000.00	2647	2022-10-25	3
1	2647	2022-10-25	1500000.00	2648	2022-10-26	2
1	2648	2022-10-26	1500000.00	2649	2022-10-27	2
1	2649	2022-10-27	5000000.00	2650	2022-10-28	2
1	2650	2022-10-28	1500000.00	2651	2022-10-29	1
1	2651	2022-10-29	1500000.00	2652	2022-10-31	1
1	2652	2022-10-31	1500000.00	2653	2022-11-01	3
1	2653	2022-11-01	1500000.00	2654	2022-11-03	2
1	2654	2022-11-03	1500000.00	2655	2022-11-04	4
1	2655	2022-11-04	1500000.00	2656	2022-11-05	2
1	2656	2022-11-05	1500000.00	2657	2022-11-07	1
1	2657	2022-11-07	1500000.00	2658	2022-11-08	2
1	2658	2022-11-08	1500000.00	2659	2022-11-09	1
1	2659	2022-11-09	5000000.00	2660	2022-11-10	3
1	2660	2022-11-10	1500000.00	2661	2022-11-11	4
1	2661	2022-11-11	1500000.00	2662	2022-11-12	1
1	2662	2022-11-12	1500000.00	2663	2022-11-14	3
1	2663	2022-11-14	1500000.00	2664	2022-11-16	1
1	2664	2022-11-16	1500000.00	2665	2022-11-17	5
1	2665	2022-11-17	1500000.00	2666	2022-11-18	2
1	2666	2022-11-18	1500000.00	2667	2022-11-19	2
1	2667	2022-11-19	1500000.00	2668	2022-11-21	1
1	2668	2022-11-21	1500000.00	2669	2022-11-22	1
1	2669	2022-11-22	5000000.00	2670	2022-11-23	1
1	2670	2022-11-23	1500000.00	2671	2022-11-24	4
1	2671	2022-11-24	1500000.00	2672	2022-11-25	3
1	2672	2022-11-25	1500000.00	2673	2022-11-26	6
1	2673	2022-11-26	3000000.00	2674	2022-11-28	0
1	2674	2022-11-28	6000000.00	2675	2022-11-29	0
1	2675	2022-11-29	1500000.00	2676	2022-11-30	13
1	2676	2022-11-30	1500000.00	2677	2022-12-01	1
1	2677	2022-12-01	1000000.00	2678	2022-12-02	8
1	2678	2022-12-02	1500000.00	2679	2022-12-03	2
1	2679	2022-12-03	4000000.00	2680	2022-12-05	1
1	2680	2022-12-05	1500000.00	2681	2022-12-06	7
1	2681	2022-12-06	1500000.00	2682	2022-12-07	1
1	2682	2022-12-07	4000000.00	2683	2022-12-08	0
1	2683	2022-12-08	1500000.00	2684	2022-12-09	2
1	2684	2022-12-09	3500000.00	2685	2022-12-10	0
1	2685	2022-12-10	1500000.00	2686	2022-12-12	1
1	2686	2022-12-12	1500000.00	2687	2022-12-13	1
1	2687	2022-12-13	1500000.00	2688	2022-12-14	3
1	2688	2022-12-14	1500000.00	2689	2022-12-15	1
1	2689	2022-12-15	4500000.00	2690	2022-12-16	3
1	2690	2022-12-16	1500000.00	2691	2022-12-17	3
1	2691	2022-12-17	1500000.00	2692	2022-12-19	4
1	2692	2022-12-19	1500000.00	2693	2022-12-20	3
1	2693	2022-12-20	1500000.00	2694	2022-12-21	1
1	2694	2022-12-21	1500000.00	2695	2022-12-22	1
1	2695	2022-12-22	1500000.00	2696	2022-12-23	2
1	2696	2022-12-23	1000000.00	2697	2022-12-24	1
1	2697	2022-12-24	1500000.00	2698	2022-12-26	2
1	2698	2022-12-26	1500000.00	2699	2022-12-27	1
1	2699	2022-12-27	5000000.00	2700	2022-12-28	1
1	2700	2022-12-28	1500000.00	2701	2022-12-29	4
1	2701	2022-12-29	1500000.00	2702	2022-12-30	3
1	2702	2022-12-30	1000000.00	2703	2022-12-31	3
1	2703	2022-12-31	1500000.00	2704	2023-01-03	6
1	2704	2023-01-03	1500000.00	2705	2023-01-04	2
1	2705	2023-01-04	4300000.00	2706	2023-01-05	0
1	2706	2023-01-05	7500000.00	2707	2023-01-06	0
1	2707	2023-01-06	1500000.00	2708	2023-01-07	1
1	2708	2023-01-07	1500000.00	2709	2023-01-09	2
1	2709	2023-01-09	5000000.00	2710	2023-01-10	2
1	2710	2023-01-10	1500000.00	2711	2023-01-11	5
1	2711	2023-01-11	1500000.00	2712	2023-01-12	1
1	2712	2023-01-12	1500000.00	2713	2023-01-13	4
1	2713	2023-01-13	1500000.00	2714	2023-01-14	4
1	2714	2023-01-14	1500000.00	2715	2023-01-16	2
1	2715	2023-01-16	1500000.00	2716	2023-01-17	1
1	2716	2023-01-17	1500000.00	2717	2023-01-18	1
1	2717	2023-01-18	1500000.00	2718	2023-01-19	6
1	2718	2023-01-19	4000000.00	2719	2023-01-20	0
1	2719	2023-01-20	5000000.00	2720	2023-01-21	8
1	2720	2023-01-21	1500000.00	2721	2023-01-23	5
1	2721	2023-01-23	1500000.00	2722	2023-01-24	3
1	2722	2023-01-24	1500000.00	2723	2023-01-25	8
1	2723	2023-01-25	1500000.00	2724	2023-01-26	1
1	2724	2023-01-26	1500000.00	2725	2023-01-27	2
1	2725	2023-01-27	1500000.00	2726	2023-01-28	4
1	2726	2023-01-28	1500000.00	2727	2023-01-30	3
1	2727	2023-01-30	1500000.00	2728	2023-01-31	4
1	2728	2023-01-31	4000000.00	2729	2023-02-01	0
1	2729	2023-02-01	5000000.00	2730	2023-02-02	3
1	2730	2023-02-02	1500000.00	2731	2023-02-03	3
1	2731	2023-02-03	1500000.00	2732	2023-02-04	2
1	2732	2023-02-04	1500000.00	2733	2023-02-06	4
1	2733	2023-02-06	1500000.00	2734	2023-02-07	2
1	2734	2023-02-07	1500000.00	2735	2023-02-08	1
1	2735	2023-02-08	1500000.00	2736	2023-02-09	3
1	2736	2023-02-09	4000000.00	2737	2023-02-10	0
1	2737	2023-02-10	1500000.00	2738	2023-02-11	1
1	2738	2023-02-11	1500000.00	2739	2023-02-13	2
1	2739	2023-02-13	5000000.00	2740	2023-02-14	1
1	2740	2023-02-14	1500000.00	2741	2023-02-15	7
1	2741	2023-02-15	1500000.00	2742	2023-02-16	4
1	2742	2023-02-16	1500000.00	2743	2023-02-17	1
1	2743	2023-02-17	1500000.00	2744	2023-02-18	1
1	2744	2023-02-18	1500000.00	2745	2023-02-22	1
1	2745	2023-02-22	1500000.00	2746	2023-02-23	1
1	2746	2023-02-23	1500000.00	2747	2023-02-24	7
1	2747	2023-02-24	1500000.00	2748	2023-02-25	3
1	2748	2023-02-25	1500000.00	2749	2023-02-27	1
1	2749	2023-02-27	5000000.00	2750	2023-02-28	2
1	2750	2023-02-28	1500000.00	2751	2023-03-01	2
1	2751	2023-03-01	1500000.00	2752	2023-03-02	4
1	2752	2023-03-02	1500000.00	2753	2023-03-03	4
1	2753	2023-03-03	1500000.00	2754	2023-03-04	2
1	2754	2023-03-04	1500000.00	2755	2023-03-06	1
1	2755	2023-03-06	1500000.00	2756	2023-03-07	2
1	2756	2023-03-07	1500000.00	2757	2023-03-08	1
1	2757	2023-03-08	1500000.00	2758	2023-03-09	4
1	2758	2023-03-09	1500000.00	2759	2023-03-10	1
1	2759	2023-03-10	5000000.00	2760	2023-03-11	4
1	2760	2023-03-11	1500000.00	2761	2023-03-13	6
1	2761	2023-03-13	1500000.00	2762	2023-03-14	1
1	2762	2023-03-14	1500000.00	2763	2023-03-15	1
1	2763	2023-03-15	1500000.00	2764	2023-03-16	2
1	2764	2023-03-16	1500000.00	2765	2023-03-17	1
1	2765	2023-03-17	1500000.00	2766	2023-03-18	2
1	2766	2023-03-18	1500000.00	2767	2023-03-20	5
1	2767	2023-03-20	4500000.00	2768	2023-03-21	0
1	2768	2023-03-21	1500000.00	2769	2023-03-22	10
1	2769	2023-03-22	5000000.00	2770	2023-03-23	5
1	2770	2023-03-23	1500000.00	2771	2023-03-24	4
1	2771	2023-03-24	1500000.00	2772	2023-03-25	3
1	2772	2023-03-25	1500000.00	2773	2023-03-27	2
1	2773	2023-03-27	1500000.00	2774	2023-03-28	4
1	2774	2023-03-28	3500000.00	2775	2023-03-29	0
1	2775	2023-03-29	1500000.00	2776	2023-03-30	1
1	2776	2023-03-30	1500000.00	2777	2023-03-31	1
1	2777	2023-03-31	4500000.00	2778	2023-04-01	0
1	2778	2023-04-01	1500000.00	2779	2023-04-03	7
1	2779	2023-04-03	5000000.00	2780	2023-04-04	2
1	2780	2023-04-04	1500000.00	2781	2023-04-05	4
1	2781	2023-04-05	1500000.00	2782	2023-04-06	2
1	2782	2023-04-06	4500000.00	2783	2023-04-08	0
1	2783	2023-04-08	1500000.00	2784	2023-04-10	4
1	2784	2023-04-10	1500000.00	2785	2023-04-11	1
1	2785	2023-04-11	1500000.00	2786	2023-04-12	4
1	2786	2023-04-12	1500000.00	2787	2023-04-13	1
1	2787	2023-04-13	1500000.00	2788	2023-04-14	1
1	2788	2023-04-14	1500000.00	2789	2023-04-15	3
1	2789	2023-04-15	8000000.00	2790	2023-04-17	0
1	2790	2023-04-17	1500000.00	2791	2023-04-18	5
1	2791	2023-04-18	1500000.00	2792	2023-04-19	1
1	2792	2023-04-19	1500000.00	2793	2023-04-20	1
1	2793	2023-04-20	1500000.00	2794	2023-04-22	1
1	2794	2023-04-22	1500000.00	2795	2023-04-24	1
1	2795	2023-04-24	1500000.00	2796	2023-04-25	1
1	2796	2023-04-25	1500000.00	2797	2023-04-26	2
1	2797	2023-04-26	1500000.00	2798	2023-04-27	1
1	2798	2023-04-27	1500000.00	2799	2023-04-28	6
1	2799	2023-04-28	5000000.00	2800	2023-04-29	3
1	2800	2023-04-29	1500000.00	2801	2023-05-02	4
1	2801	2023-05-02	1500000.00	2802	2023-05-03	3
1	2802	2023-05-03	1500000.00	2803	2023-05-04	3
1	2803	2023-05-04	1700000.00	2804	2023-05-05	1
1	2804	2023-05-05	5000000.00	2805	2023-05-06	0
1	2805	2023-05-06	1700000.00	2806	2023-05-08	1
1	2806	2023-05-08	5000000.00	2807	2023-05-09	0
1	2807	2023-05-09	1700000.00	2808	2023-05-10	2
1	2808	2023-05-10	5000000.00	2809	2023-05-11	0
1	2809	2023-05-11	5000000.00	2810	2023-05-12	1
1	2810	2023-05-12	1700000.00	2811	2023-05-13	2
1	2811	2023-05-13	1700000.00	2812	2023-05-15	2
1	2812	2023-05-15	1700000.00	2813	2023-05-16	4
1	2813	2023-05-16	1700000.00	2814	2023-05-17	1
1	2814	2023-05-17	1700000.00	2815	2023-05-18	7
1	2815	2023-05-18	1700000.00	2816	2023-05-19	1
1	2816	2023-05-19	1700000.00	2817	2023-05-20	3
1	2817	2023-05-20	1700000.00	2818	2023-05-22	1
1	2818	2023-05-22	1700000.00	2819	2023-05-23	1
1	2819	2023-05-23	6000000.00	2820	2023-05-24	0
1	2820	2023-05-24	1700000.00	2821	2023-05-25	6
1	2821	2023-05-25	1700000.00	2822	2023-05-26	2
1	2822	2023-05-26	1700000.00	2823	2023-05-27	2
1	2823	2023-05-27	5000000.00	2824	2023-05-29	0
1	2824	2023-05-29	1700000.00	2825	2023-05-30	2
1	2825	2023-05-30	1700000.00	2826	2023-05-31	1
1	2826	2023-05-31	3800000.00	2827	2023-06-01	0
1	2827	2023-06-01	1700000.00	2828	2023-06-02	2
1	2828	2023-06-02	5000000.00	2829	2023-06-03	0
1	2829	2023-06-03	12000000.00	2830	2023-06-05	0
1	2830	2023-06-05	2000000.00	2831	2023-06-06	11
1	2831	2023-06-06	2000000.00	2832	2023-06-07	1
1	2832	2023-06-07	1700000.00	2833	2023-06-09	2
1	2833	2023-06-09	1700000.00	2834	2023-06-10	1
1	2834	2023-06-10	1700000.00	2835	2023-06-12	1
1	2835	2023-06-12	5000000.00	2836	2023-06-13	0
1	2836	2023-06-13	1700000.00	2837	2023-06-14	4
1	2837	2023-06-14	4500000.00	2838	2023-06-15	0
1	2838	2023-06-15	1700000.00	2839	2023-06-16	2
1	2839	2023-06-16	4500000.00	2840	2023-06-17	3
1	2840	2023-06-17	1700000.00	2841	2023-06-19	4
1	2841	2023-06-19	1700000.00	2842	2023-06-20	2
1	2842	2023-06-20	1700000.00	2843	2023-06-21	1
1	2843	2023-06-21	1700000.00	2844	2023-06-22	3
1	2844	2023-06-22	4000000.00	2845	2023-06-23	0
1	2845	2023-06-23	1700000.00	2846	2023-06-24	1
1	2846	2023-06-24	1700000.00	2847	2023-06-26	1
1	2847	2023-06-26	1700000.00	2848	2023-06-27	3
1	2848	2023-06-27	1700000.00	2849	2023-06-28	1
1	2849	2023-06-28	5000000.00	2850	2023-06-29	3
1	2850	2023-06-29	1700000.00	2851	2023-06-30	3
1	2851	2023-06-30	1700000.00	2852	2023-07-01	2
1	2852	2023-07-01	1700000.00	2853	2023-07-03	3
1	2853	2023-07-03	1700000.00	2854	2023-07-04	2
1	2854	2023-07-04	1700000.00	2855	2023-07-05	3
1	2855	2023-07-05	5000000.00	2856	2023-07-06	0
1	2856	2023-07-06	1700000.00	2857	2023-07-07	5
1	2857	2023-07-07	5000000.00	2858	2023-07-08	0
1	2858	2023-07-08	1700000.00	2859	2023-07-10	4
1	2859	2023-07-10	5000000.00	2860	2023-07-11	2
1	2860	2023-07-11	1700000.00	2861	2023-07-12	4
1	2861	2023-07-12	4500000.00	2862	2023-07-13	0
1	2862	2023-07-13	1700000.00	2863	2023-07-14	2
1	2863	2023-07-14	4500000.00	2864	2023-07-15	0
1	2864	2023-07-15	1700000.00	2865	2023-07-17	2
1	2865	2023-07-17	1700000.00	2866	2023-07-18	1
1	2866	2023-07-18	4000000.00	2867	2023-07-19	0
1	2867	2023-07-19	1700000.00	2868	2023-07-20	2
1	2868	2023-07-20	1700000.00	2869	2023-07-21	2
1	2869	2023-07-21	5000000.00	2870	2023-07-22	2
1	2870	2023-07-22	1700000.00	2871	2023-07-24	1
1	2871	2023-07-24	4000000.00	2872	2023-07-25	0
1	2872	2023-07-25	1700000.00	2873	2023-07-26	3
1	2873	2023-07-26	1700000.00	2874	2023-07-27	2
1	2874	2023-07-27	1700000.00	2875	2023-07-28	2
1	2875	2023-07-28	4500000.00	2876	2023-07-29	0
1	2876	2023-07-29	1700000.00	2877	2023-07-31	4
1	2877	2023-07-31	1700000.00	2878	2023-08-01	9
1	2878	2023-08-01	1700000.00	2879	2023-08-02	3
1	2879	2023-08-02	5000000.00	2880	2023-08-03	1
1	2880	2023-08-03	1700000.00	2881	2023-08-04	3
1	2881	2023-08-04	1700000.00	2882	2023-08-05	3
1	2882	2023-08-05	5000000.00	2883	2023-08-07	0
1	2883	2023-08-07	1700000.00	2884	2023-08-08	4
1	2884	2023-08-08	1700000.00	2885	2023-08-09	2
1	2885	2023-08-09	4500000.00	2886	2023-08-10	0
1	2886	2023-08-10	1700000.00	2887	2023-08-11	19
1	2887	2023-08-11	1700000.00	2888	2023-08-12	6
1	2888	2023-08-12	1700000.00	2889	2023-08-14	18
1	2889	2023-08-14	5000000.00	2890	2023-08-15	5
1	2890	2023-08-15	1700000.00	2891	2023-08-16	2
1	2891	2023-08-16	1700000.00	2892	2023-08-17	2
1	2892	2023-08-17	1700000.00	2893	2023-08-18	2
1	2893	2023-08-18	4000000.00	2894	2023-08-19	0
1	2894	2023-08-19	1700000.00	2895	2023-08-21	2
1	2895	2023-08-21	4000000.00	2896	2023-08-22	0
1	2896	2023-08-22	1700000.00	2897	2023-08-23	3
1	2897	2023-08-23	1700000.00	2898	2023-08-24	2
1	2898	2023-08-24	4000000.00	2899	2023-08-25	0
1	2899	2023-08-25	200000000.00	2900	2023-09-09	4
1	2900	2023-09-09	1700000.00	2901	2023-09-11	65
1	2901	2023-09-11	1700000.00	2902	2023-09-12	1
1	2902	2023-09-12	1700000.00	2903	2023-09-13	1
1	2903	2023-09-13	4000000.00	2904	2023-09-14	0
1	2904	2023-09-14	1700000.00	2905	2023-09-15	3
1	2905	2023-09-15	1700000.00	2906	2023-09-16	2
1	2906	2023-09-16	1700000.00	2907	2023-09-18	1
1	2907	2023-09-18	1700000.00	2908	2023-09-19	1
1	2908	2023-09-19	1700000.00	2909	2023-09-20	1
1	2909	2023-09-20	6500000.00	2910	2023-09-21	0
1	2910	2023-09-21	1700000.00	2911	2023-09-22	2
1	2911	2023-09-22	1700000.00	2912	2023-09-23	2
1	2912	2023-09-23	4000000.00	2913	2023-09-25	0
1	2913	2023-09-25	1700000.00	2914	2023-09-26	3
1	2914	2023-09-26	1700000.00	2915	2023-09-27	3
1	2915	2023-09-27	4000000.00	2916	2023-09-28	0
1	2916	2023-09-28	1700000.00	2917	2023-09-29	2
1	2917	2023-09-29	1700000.00	2918	2023-09-30	4
1	2918	2023-09-30	1700000.00	2919	2023-10-02	1
1	2919	2023-10-02	5000000.00	2920	2023-10-03	1
1	2920	2023-10-03	1700000.00	2921	2023-10-04	7
1	2921	2023-10-04	4000000.00	2922	2023-10-05	0
1	2922	2023-10-05	1700000.00	2923	2023-10-06	2
1	2923	2023-10-06	1700000.00	2924	2023-10-07	2
1	2924	2023-10-07	4000000.00	2925	2023-10-09	0
1	2925	2023-10-09	1700000.00	2926	2023-10-10	5
1	2926	2023-10-10	1700000.00	2927	2023-10-11	2
1	2927	2023-10-11	5000000.00	2928	2023-10-13	0
1	2928	2023-10-13	1700000.00	2929	2023-10-14	5
1	2929	2023-10-14	5000000.00	2930	2023-10-16	5
1	2930	2023-10-16	1700000.00	2931	2023-10-17	3
1	2931	2023-10-17	1700000.00	2932	2023-10-18	1
1	2932	2023-10-18	1700000.00	2933	2023-10-19	1
1	2933	2023-10-19	1700000.00	2934	2023-10-20	4
1	2934	2023-10-20	1700000.00	2935	2023-10-21	3
1	2935	2023-10-21	1700000.00	2936	2023-10-23	1
1	2936	2023-10-23	1700000.00	2937	2023-10-24	1
1	2937	2023-10-24	1700000.00	2938	2023-10-25	1
1	2938	2023-10-25	1700000.00	2939	2023-10-26	1
1	2939	2023-10-26	5000000.00	2940	2023-10-27	2
1	2940	2023-10-27	1700000.00	2941	2023-10-28	1
1	2941	2023-10-28	4000000.00	2942	2023-10-30	0
1	2942	2023-10-30	1700000.00	2943	2023-10-31	3
1	2943	2023-10-31	4000000.00	2944	2023-11-01	0
1	2944	2023-11-01	1700000.00	2945	2023-11-03	1
1	2945	2023-11-03	1700000.00	2946	2023-11-04	1
1	2946	2023-11-04	1700000.00	2947	2023-11-06	2
1	2947	2023-11-06	4200000.00	2948	2023-11-07	0
1	2948	2023-11-07	1700000.00	2949	2023-11-08	4
1	2949	2023-11-08	5000000.00	2950	2023-11-09	2
1	2950	2023-11-09	1700000.00	2951	2023-11-10	3
1	2951	2023-11-10	1700000.00	2952	2023-11-11	2
1	2952	2023-11-11	1700000.00	2953	2023-11-13	3
1	2953	2023-11-13	1700000.00	2954	2023-11-14	2
1	2954	2023-11-14	1700000.00	2955	2023-11-16	3
1	2955	2023-11-16	1700000.00	2956	2023-11-17	2
1	2956	2023-11-17	1700000.00	2957	2023-11-18	5
1	2957	2023-11-18	1700000.00	2958	2023-11-20	1
1	2958	2023-11-20	1700000.00	2959	2023-11-21	1
1	2959	2023-11-21	5000000.00	2960	2023-11-22	2
1	2960	2023-11-22	1700000.00	2961	2023-11-23	3
1	2961	2023-11-23	1700000.00	2962	2023-11-24	2
1	2962	2023-11-24	1700000.00	2963	2023-11-25	4
1	2963	2023-11-25	4000000.00	2964	2023-11-27	0
1	2964	2023-11-27	1700000.00	2965	2023-11-28	10
1	2965	2023-11-28	1700000.00	2966	2023-11-29	1
1	2966	2023-11-29	1700000.00	2967	2023-11-30	1
1	2967	2023-11-30	1700000.00	2968	2023-12-01	1
1	2968	2023-12-01	1700000.00	2969	2023-12-02	2
1	2969	2023-12-02	7500000.00	2970	2023-12-04	0
1	2970	2023-12-04	13000000.00	2971	2023-12-05	0
1	2971	2023-12-05	1700000.00	2972	2023-12-06	3
1	2972	2023-12-06	1700000.00	2973	2023-12-07	3
1	2973	2023-12-07	1700000.00	2974	2023-12-08	1
1	2974	2023-12-08	4000000.00	2975	2023-12-09	0
1	2975	2023-12-09	1700000.00	2976	2023-12-11	1
1	2976	2023-12-11	1700000.00	2977	2023-12-12	4
1	2977	2023-12-12	3500000.00	2978	2023-12-13	0
1	2978	2023-12-13	1700000.00	2979	2023-12-14	2
1	2979	2023-12-14	6000000.00	2980	2023-12-15	4
1	2980	2023-12-15	1700000.00	2981	2023-12-16	1
1	2981	2023-12-16	1700000.00	2982	2023-12-18	3
1	2982	2023-12-18	1700000.00	2983	2023-12-19	3
1	2984	2023-12-20	1700000.00	2985	2023-12-21	4
1	2985	2023-12-21	1700000.00	2986	2023-12-22	1
1	2986	2023-12-22	4000000.00	2987	2023-12-23	0
1	2987	2023-12-23	1700000.00	2988	2023-12-26	1
1	2988	2023-12-26	4000000.00	2989	2023-12-27	0
1	2989	2023-12-27	5000000.00	2990	2023-12-28	1
1	2991	2023-12-29	1700000.00	2992	2023-12-30	1
1	2992	2023-12-30	1700000.00	2993	2024-01-02	1
1	2993	2024-01-02	1700000.00	2994	2024-01-03	1
1	2994	2024-01-03	4500000.00	2995	2024-01-04	0
1	2995	2024-01-04	1700000.00	2996	2024-01-05	4
1	2996	2024-01-05	4500000.00	2997	2024-01-06	0
1	2997	2024-01-06	1700000.00	2998	2024-01-08	3
1	2999	2024-01-09	5000000.00	3000	2024-01-10	2
1	3000	2024-01-10	1700000.00	3001	2024-01-11	7
1	3001	2024-01-11	1700000.00	3002	2024-01-12	4
1	3002	2024-01-12	4500000.00	3003	2024-01-13	0
1	3003	2024-01-13	1700000.00	3004	2024-01-15	8
1	3004	2024-01-15	1700000.00	3005	2024-01-16	6
1	3005	2024-01-16	1700000.00	3006	2024-01-17	2
1	3006	2024-01-17	1700000.00	3007	2024-01-18	3
1	3007	2024-01-18	1700000.00	3008	2024-01-19	1
1	3008	2024-01-19	1700000.00	3009	2024-01-20	2
1	3009	2024-01-20	5000000.00	3010	2024-01-22	4
1	3010	2024-01-22	1700000.00	3011	2024-01-23	2
1	3011	2024-01-23	1700000.00	3012	2024-01-24	2
1	3012	2024-01-24	4200000.00	3013	2024-01-25	0
1	3015	2024-01-27	4000000.00	3016	2024-01-29	0
1	3016	2024-01-29	1700000.00	3017	2024-01-30	8
1	3017	2024-01-30	1700000.00	3018	2024-01-31	2
1	3018	2024-01-31	1700000.00	3019	2024-02-01	4
1	3019	2024-02-01	5000000.00	3020	2024-02-02	2
1	3020	2024-02-02	1700000.00	3021	2024-02-03	4
1	3021	2024-02-03	1700000.00	3022	2024-02-05	2
1	3022	2024-02-05	4700000.00	3023	2024-02-06	0
1	3024	2024-02-07	1700000.00	3025	2024-02-08	5
1	3025	2024-02-08	1700000.00	3026	2024-02-09	1
1	3026	2024-02-09	1700000.00	3027	2024-02-10	2
1	3027	2024-02-10	4000000.00	3028	2024-02-14	0
1	3028	2024-02-14	1700000.00	3029	2024-02-15	1
1	3029	2024-02-15	6800000.00	3030	2024-02-16	0
1	3031	2024-02-17	1700000.00	3032	2024-02-19	2
1	3032	2024-02-19	1700000.00	3033	2024-02-20	2
1	3033	2024-02-20	1700000.00	3034	2024-02-21	7
1	3035	2024-02-22	1700000.00	3036	2024-02-23	7
1	3036	2024-02-23	1700000.00	3037	2024-02-24	2
1	3037	2024-02-24	1700000.00	3038	2024-02-26	1
1	3038	2024-02-26	1700000.00	3039	2024-02-27	1
1	3039	2024-02-27	5000000.00	3040	2024-02-28	2
1	3040	2024-02-28	1700000.00	3041	2024-02-29	3
1	3041	2024-02-29	3600000.00	3042	2024-03-01	0
1	3042	2024-03-01	1700000.00	3043	2024-03-02	2
1	3043	2024-03-02	1700000.00	3044	2024-03-04	2
1	3044	2024-03-04	1700000.00	3045	2024-03-05	1
1	3045	2024-03-05	1700000.00	3046	2024-03-06	5
1	3046	2024-03-06	1700000.00	3047	2024-03-07	2
1	3047	2024-03-07	1700000.00	3048	2024-03-08	4
1	3048	2024-03-08	4000000.00	3049	2024-03-09	0
1	3049	2024-03-09	5000000.00	3050	2024-03-11	2
1	3050	2024-03-11	11500000.00	3051	2024-03-12	0
1	3052	2024-03-13	1700000.00	3053	2024-03-14	6
1	3053	2024-03-14	1700000.00	3054	2024-03-15	3
1	3093	2024-05-02	1700000.00	3094	2024-05-03	3
\.


--
-- Data for Name: parametro; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parametro (id_parametro, nm_base_url_atualizacao) FROM stdin;
1	https://servicebus2.caixa.gov.br/
\.


--
-- Data for Name: sorteio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sorteio (id_tipo_jogo, nr_concurso, nr_sorteado) FROM stdin;
1	94	2
1	94	4
1	1	2
1	1	3
1	1	5
1	1	6
1	1	9
1	1	10
1	1	11
1	1	13
1	1	14
1	1	16
1	1	18
1	1	20
1	1	23
1	1	24
1	1	25
1	2	1
1	2	4
1	2	5
1	2	6
1	2	7
1	2	9
1	2	11
1	2	12
1	2	13
1	2	15
1	2	16
1	2	19
1	2	20
1	2	23
1	2	24
1	3	1
1	3	4
1	3	6
1	3	7
1	3	8
1	3	9
1	3	10
1	3	11
1	3	12
1	3	14
1	3	16
1	3	17
1	3	20
1	3	23
1	3	24
1	4	1
1	4	2
1	4	4
1	4	5
1	4	8
1	4	10
1	4	12
1	4	13
1	4	16
1	4	17
1	4	18
1	4	19
1	4	23
1	4	24
1	4	25
1	5	1
1	5	2
1	5	4
1	5	8
1	5	9
1	5	11
1	5	12
1	5	13
1	5	15
1	5	16
1	5	19
1	5	20
1	5	23
1	5	24
1	5	25
1	6	1
1	6	2
1	6	4
1	6	5
1	6	6
1	6	7
1	6	10
1	6	12
1	6	15
1	6	16
1	6	17
1	6	19
1	6	21
1	6	23
1	6	25
1	7	1
1	7	4
1	7	7
1	7	8
1	7	10
1	7	12
1	7	14
1	7	15
1	7	16
1	7	18
1	7	19
1	7	21
1	7	22
1	7	23
1	7	25
1	8	1
1	8	5
1	8	6
1	8	8
1	8	9
1	8	10
1	8	13
1	8	15
1	8	16
1	8	17
1	8	18
1	8	19
1	8	20
1	8	22
1	8	25
1	9	3
1	9	4
1	9	5
1	9	9
1	9	10
1	9	11
1	9	13
1	9	15
1	9	16
1	9	17
1	9	19
1	9	20
1	9	21
1	9	24
1	9	25
1	10	2
1	10	3
1	10	4
1	10	5
1	10	6
1	10	8
1	10	9
1	10	10
1	10	11
1	10	12
1	10	14
1	10	19
1	10	20
1	10	23
1	10	24
1	11	2
1	11	6
1	11	7
1	11	8
1	11	9
1	11	10
1	11	11
1	11	12
1	11	16
1	11	19
1	11	20
1	11	22
1	11	23
1	11	24
1	11	25
1	12	1
1	12	2
1	12	4
1	12	5
1	12	7
1	12	8
1	12	9
1	12	10
1	12	11
1	12	12
1	12	14
1	12	16
1	12	17
1	12	24
1	12	25
1	13	3
1	13	5
1	13	6
1	13	7
1	13	8
1	13	9
1	13	10
1	13	11
1	13	13
1	13	14
1	13	15
1	13	16
1	13	17
1	13	19
1	13	23
1	14	1
1	14	2
1	14	5
1	14	6
1	14	7
1	14	9
1	14	13
1	14	14
1	14	15
1	14	18
1	14	19
1	14	20
1	14	21
1	14	23
1	14	25
1	15	1
1	15	2
1	15	4
1	15	6
1	15	8
1	15	10
1	15	12
1	15	15
1	15	16
1	15	18
1	15	19
1	15	21
1	15	23
1	15	24
1	15	25
1	16	2
1	16	5
1	16	6
1	16	7
1	16	8
1	16	10
1	16	12
1	16	13
1	16	15
1	16	17
1	16	19
1	16	21
1	16	23
1	16	24
1	16	25
1	17	1
1	17	2
1	17	3
1	17	5
1	17	6
1	17	7
1	17	9
1	17	13
1	17	14
1	17	16
1	17	17
1	17	18
1	17	19
1	17	20
1	17	21
1	18	2
1	18	6
1	18	7
1	18	8
1	18	10
1	18	11
1	18	14
1	18	15
1	18	17
1	18	18
1	18	19
1	18	20
1	18	22
1	18	23
1	18	24
1	19	2
1	19	5
1	19	6
1	19	7
1	19	8
1	19	10
1	19	11
1	19	13
1	19	14
1	19	15
1	19	16
1	19	17
1	19	20
1	19	23
1	19	24
1	20	3
1	20	4
1	20	6
1	20	7
1	20	8
1	20	9
1	20	10
1	20	14
1	20	16
1	20	17
1	20	18
1	20	19
1	20	20
1	20	23
1	20	24
1	21	1
1	21	2
1	21	4
1	21	5
1	21	8
1	21	11
1	21	14
1	21	16
1	21	18
1	21	19
1	21	20
1	21	22
1	21	23
1	21	24
1	21	25
1	22	1
1	22	2
1	22	3
1	22	4
1	22	5
1	22	6
1	22	7
1	22	9
1	22	10
1	22	12
1	22	13
1	22	14
1	22	15
1	22	22
1	22	25
1	23	1
1	23	3
1	23	4
1	23	5
1	23	6
1	23	8
1	23	10
1	23	11
1	23	12
1	23	14
1	23	16
1	23	17
1	23	18
1	23	19
1	23	20
1	24	1
1	24	2
1	24	3
1	24	5
1	24	7
1	24	10
1	24	11
1	24	14
1	24	17
1	24	19
1	24	20
1	24	21
1	24	23
1	24	24
1	24	25
1	25	1
1	25	2
1	25	3
1	25	4
1	25	5
1	25	6
1	25	7
1	25	9
1	25	13
1	25	14
1	25	16
1	25	20
1	25	22
1	25	23
1	25	24
1	26	5
1	26	7
1	26	8
1	26	9
1	26	10
1	26	11
1	26	13
1	26	14
1	26	16
1	26	17
1	26	19
1	26	20
1	26	21
1	26	22
1	26	23
1	27	3
1	27	6
1	27	8
1	27	10
1	27	11
1	27	12
1	27	13
1	27	14
1	27	15
1	27	18
1	27	20
1	27	21
1	27	22
1	27	24
1	27	25
1	28	1
1	28	3
1	28	7
1	28	9
1	28	10
1	28	11
1	28	12
1	28	13
1	28	14
1	28	16
1	28	17
1	28	18
1	28	19
1	28	20
1	28	21
1	29	1
1	29	4
1	29	5
1	29	6
1	29	8
1	29	9
1	29	13
1	29	14
1	29	16
1	29	17
1	29	19
1	29	20
1	29	21
1	29	22
1	29	24
1	30	1
1	30	2
1	30	3
1	30	4
1	30	6
1	30	7
1	30	8
1	30	11
1	30	14
1	30	17
1	30	19
1	30	20
1	30	21
1	30	22
1	30	23
1	31	1
1	31	2
1	31	3
1	31	4
1	31	9
1	31	13
1	31	14
1	31	15
1	31	17
1	31	19
1	31	20
1	31	21
1	31	22
1	31	24
1	31	25
1	32	1
1	32	2
1	32	4
1	32	6
1	32	7
1	32	9
1	32	10
1	32	11
1	32	14
1	32	15
1	32	16
1	32	17
1	32	20
1	32	22
1	32	23
1	33	1
1	33	2
1	33	5
1	33	7
1	33	8
1	33	10
1	33	11
1	33	12
1	33	14
1	33	16
1	33	19
1	33	20
1	33	21
1	33	23
1	33	24
1	34	1
1	34	2
1	34	4
1	34	7
1	34	8
1	34	9
1	34	10
1	34	11
1	34	15
1	34	16
1	34	18
1	34	19
1	34	20
1	34	21
1	34	23
1	35	1
1	35	4
1	35	5
1	35	6
1	35	11
1	35	12
1	35	13
1	35	14
1	35	16
1	35	17
1	35	19
1	35	21
1	35	22
1	35	23
1	35	25
1	36	1
1	36	4
1	36	5
1	36	7
1	36	8
1	36	10
1	36	11
1	36	14
1	36	17
1	36	19
1	36	20
1	36	21
1	36	22
1	36	23
1	36	24
1	37	1
1	37	3
1	37	4
1	37	5
1	37	8
1	37	9
1	37	10
1	37	11
1	37	13
1	37	15
1	37	20
1	37	21
1	37	22
1	37	23
1	37	24
1	38	1
1	38	2
1	38	3
1	38	6
1	38	7
1	38	8
1	38	9
1	38	10
1	38	13
1	38	14
1	38	15
1	38	16
1	38	22
1	38	24
1	38	25
1	39	2
1	39	7
1	39	8
1	39	9
1	39	11
1	39	13
1	39	14
1	39	15
1	39	17
1	39	18
1	39	19
1	39	21
1	39	22
1	39	23
1	39	24
1	40	1
1	40	2
1	40	5
1	40	7
1	40	8
1	40	10
1	40	12
1	40	13
1	40	14
1	40	16
1	40	17
1	40	20
1	40	21
1	40	22
1	40	24
1	41	2
1	41	3
1	41	4
1	41	9
1	41	12
1	41	13
1	41	15
1	41	16
1	41	17
1	41	18
1	41	19
1	41	20
1	41	21
1	41	23
1	41	25
1	42	1
1	42	3
1	42	4
1	42	5
1	42	6
1	42	8
1	42	11
1	42	12
1	42	14
1	42	15
1	42	17
1	42	21
1	42	22
1	42	24
1	42	25
1	43	1
1	43	3
1	43	6
1	43	7
1	43	8
1	43	9
1	43	10
1	43	14
1	43	17
1	43	18
1	43	19
1	43	20
1	43	22
1	43	23
1	43	24
1	44	3
1	44	4
1	44	5
1	44	6
1	44	10
1	44	11
1	44	12
1	44	13
1	44	14
1	44	18
1	44	19
1	44	21
1	44	23
1	44	24
1	44	25
1	45	1
1	45	2
1	45	3
1	45	5
1	45	7
1	45	9
1	45	14
1	45	16
1	45	17
1	45	18
1	45	19
1	45	21
1	45	23
1	45	24
1	45	25
1	46	1
1	46	2
1	46	4
1	46	5
1	46	6
1	46	8
1	46	10
1	46	11
1	46	14
1	46	18
1	46	19
1	46	21
1	46	23
1	46	24
1	46	25
1	47	1
1	47	2
1	47	3
1	47	4
1	47	5
1	47	6
1	47	8
1	47	10
1	47	11
1	47	13
1	47	15
1	47	18
1	47	20
1	47	22
1	47	25
1	48	2
1	48	5
1	48	6
1	48	7
1	48	11
1	48	13
1	48	15
1	48	16
1	48	17
1	48	18
1	48	19
1	48	20
1	48	21
1	48	22
1	48	23
1	49	2
1	49	4
1	49	5
1	49	6
1	49	8
1	49	11
1	49	13
1	49	15
1	49	16
1	49	19
1	49	20
1	49	21
1	49	22
1	49	23
1	49	24
1	50	1
1	50	2
1	50	3
1	50	6
1	50	7
1	50	9
1	50	10
1	50	11
1	50	12
1	50	13
1	50	19
1	50	20
1	50	21
1	50	23
1	50	25
1	51	1
1	51	3
1	51	5
1	51	6
1	51	7
1	51	8
1	51	11
1	51	13
1	51	14
1	51	16
1	51	17
1	51	20
1	51	21
1	51	22
1	51	23
1	52	1
1	52	2
1	52	4
1	52	8
1	52	9
1	52	11
1	52	12
1	52	13
1	52	15
1	52	16
1	52	21
1	52	22
1	52	23
1	52	24
1	52	25
1	53	1
1	53	2
1	53	3
1	53	6
1	53	7
1	53	9
1	53	11
1	53	12
1	53	14
1	53	17
1	53	18
1	53	19
1	53	20
1	53	23
1	53	24
1	54	2
1	54	4
1	54	5
1	54	6
1	54	7
1	54	8
1	54	9
1	54	12
1	54	14
1	54	16
1	54	18
1	54	20
1	54	21
1	54	22
1	54	24
1	55	2
1	55	3
1	55	4
1	55	5
1	55	6
1	55	7
1	55	8
1	55	9
1	55	12
1	55	13
1	55	15
1	55	16
1	55	18
1	55	19
1	55	25
1	56	1
1	56	2
1	56	5
1	56	9
1	56	12
1	56	13
1	56	14
1	56	15
1	56	16
1	56	17
1	56	19
1	56	20
1	56	22
1	56	23
1	56	24
1	57	1
1	57	2
1	57	3
1	57	4
1	57	6
1	57	7
1	57	8
1	57	11
1	57	12
1	57	17
1	57	19
1	57	20
1	57	21
1	57	22
1	57	25
1	58	3
1	58	4
1	58	5
1	58	6
1	58	11
1	58	12
1	58	13
1	58	14
1	58	15
1	58	16
1	58	17
1	58	18
1	58	19
1	58	20
1	58	22
1	59	1
1	59	3
1	59	5
1	59	6
1	59	7
1	59	8
1	59	10
1	59	11
1	59	13
1	59	14
1	59	15
1	59	19
1	59	20
1	59	23
1	59	25
1	60	1
1	60	2
1	60	3
1	60	4
1	60	5
1	60	8
1	60	11
1	60	16
1	60	17
1	60	18
1	60	19
1	60	22
1	60	23
1	60	24
1	60	25
1	61	1
1	61	4
1	61	5
1	61	9
1	61	11
1	61	12
1	61	13
1	61	14
1	61	15
1	61	16
1	61	19
1	61	20
1	61	22
1	61	23
1	61	25
1	62	1
1	62	3
1	62	7
1	62	8
1	62	9
1	62	11
1	62	13
1	62	14
1	62	15
1	62	16
1	62	17
1	62	18
1	62	20
1	62	24
1	62	25
1	63	4
1	63	8
1	63	9
1	63	10
1	63	11
1	63	12
1	63	13
1	63	16
1	63	17
1	63	19
1	63	20
1	63	21
1	63	22
1	63	24
1	63	25
1	64	1
1	64	2
1	64	3
1	64	6
1	64	7
1	64	8
1	64	9
1	64	10
1	64	13
1	64	14
1	64	17
1	64	18
1	64	20
1	64	23
1	64	25
1	65	1
1	65	2
1	65	4
1	65	7
1	65	10
1	65	15
1	65	16
1	65	17
1	65	18
1	65	19
1	65	20
1	65	21
1	65	22
1	65	23
1	65	25
1	66	1
1	66	2
1	66	4
1	66	8
1	66	10
1	66	11
1	66	14
1	66	15
1	66	16
1	66	17
1	66	20
1	66	21
1	66	22
1	66	23
1	66	24
1	67	5
1	67	7
1	67	8
1	67	9
1	67	10
1	67	11
1	67	12
1	67	13
1	67	15
1	67	16
1	67	20
1	67	21
1	67	22
1	67	23
1	67	24
1	68	1
1	68	2
1	68	3
1	68	5
1	68	6
1	68	7
1	68	8
1	68	9
1	68	10
1	68	12
1	68	16
1	68	17
1	68	22
1	68	23
1	68	25
1	69	1
1	69	4
1	69	7
1	69	8
1	69	9
1	69	10
1	69	11
1	69	15
1	69	17
1	69	18
1	69	19
1	69	20
1	69	21
1	69	23
1	69	24
1	70	1
1	70	2
1	70	3
1	70	5
1	70	6
1	70	9
1	70	10
1	70	12
1	70	14
1	70	15
1	70	16
1	70	19
1	70	20
1	70	24
1	70	25
1	71	1
1	71	3
1	71	5
1	71	6
1	71	8
1	71	9
1	71	11
1	71	13
1	71	14
1	71	15
1	71	16
1	71	18
1	71	21
1	71	22
1	71	23
1	72	1
1	72	2
1	72	5
1	72	7
1	72	8
1	72	11
1	72	12
1	72	13
1	72	15
1	72	16
1	72	17
1	72	18
1	72	23
1	72	24
1	72	25
1	73	1
1	73	2
1	73	5
1	73	7
1	73	10
1	73	11
1	73	13
1	73	14
1	73	15
1	73	16
1	73	17
1	73	18
1	73	19
1	73	21
1	73	25
1	74	1
1	74	2
1	74	3
1	74	4
1	74	5
1	74	6
1	74	8
1	74	11
1	74	13
1	74	15
1	74	16
1	74	18
1	74	22
1	74	23
1	74	25
1	75	1
1	75	3
1	75	4
1	75	5
1	75	6
1	75	7
1	75	8
1	75	10
1	75	11
1	75	13
1	75	15
1	75	16
1	75	17
1	75	20
1	75	25
1	76	1
1	76	3
1	76	5
1	76	8
1	76	9
1	76	10
1	76	12
1	76	13
1	76	15
1	76	16
1	76	17
1	76	19
1	76	21
1	76	23
1	76	25
1	77	2
1	77	3
1	77	4
1	77	6
1	77	8
1	77	9
1	77	11
1	77	14
1	77	17
1	77	18
1	77	20
1	77	21
1	77	22
1	77	24
1	77	25
1	78	1
1	78	2
1	78	3
1	78	5
1	78	6
1	78	7
1	78	8
1	78	12
1	78	13
1	78	15
1	78	16
1	78	17
1	78	18
1	78	20
1	78	23
1	79	1
1	79	2
1	79	3
1	79	5
1	79	9
1	79	12
1	79	14
1	79	15
1	79	17
1	79	18
1	79	20
1	79	22
1	79	23
1	79	24
1	79	25
1	80	1
1	80	2
1	80	3
1	80	4
1	80	5
1	80	7
1	80	9
1	80	10
1	80	14
1	80	15
1	80	17
1	80	18
1	80	20
1	80	22
1	80	25
1	81	1
1	81	2
1	81	3
1	81	4
1	81	5
1	81	6
1	81	7
1	81	10
1	81	11
1	81	13
1	81	15
1	81	16
1	81	17
1	81	19
1	81	21
1	82	1
1	82	4
1	82	5
1	82	6
1	82	8
1	82	9
1	82	12
1	82	13
1	82	15
1	82	17
1	82	18
1	82	19
1	82	20
1	82	22
1	82	23
1	83	1
1	83	2
1	83	3
1	83	5
1	83	6
1	83	8
1	83	10
1	83	11
1	83	12
1	83	13
1	83	14
1	83	20
1	83	23
1	83	24
1	83	25
1	84	1
1	84	2
1	84	4
1	84	6
1	84	8
1	84	12
1	84	15
1	84	16
1	84	17
1	84	19
1	84	20
1	84	22
1	84	23
1	84	24
1	84	25
1	85	1
1	85	2
1	85	5
1	85	7
1	85	8
1	85	9
1	85	11
1	85	13
1	85	14
1	85	15
1	85	16
1	85	18
1	85	21
1	85	22
1	85	23
1	86	2
1	86	4
1	86	5
1	86	6
1	86	8
1	86	9
1	86	12
1	86	13
1	86	14
1	86	17
1	86	18
1	86	19
1	86	23
1	86	24
1	86	25
1	87	1
1	87	2
1	87	3
1	87	5
1	87	8
1	87	9
1	87	10
1	87	11
1	87	13
1	87	15
1	87	18
1	87	20
1	87	22
1	87	24
1	87	25
1	88	1
1	88	2
1	88	4
1	88	5
1	88	8
1	88	9
1	88	10
1	88	11
1	88	12
1	88	14
1	88	17
1	88	18
1	88	19
1	88	24
1	88	25
1	89	1
1	89	6
1	89	11
1	89	12
1	89	13
1	89	15
1	89	16
1	89	17
1	89	19
1	89	20
1	89	21
1	89	22
1	89	23
1	89	24
1	89	25
1	90	1
1	90	2
1	90	3
1	90	8
1	90	10
1	90	11
1	90	12
1	90	15
1	90	17
1	90	20
1	90	21
1	90	22
1	90	23
1	90	24
1	90	25
1	91	1
1	91	4
1	91	9
1	91	10
1	91	11
1	91	12
1	91	13
1	91	14
1	91	15
1	91	16
1	91	17
1	91	20
1	91	22
1	91	23
1	91	25
1	92	1
1	92	2
1	92	4
1	92	6
1	92	8
1	92	12
1	92	13
1	92	14
1	92	15
1	92	17
1	92	18
1	92	19
1	92	21
1	92	22
1	92	24
1	93	2
1	93	4
1	93	5
1	93	6
1	93	7
1	93	9
1	93	10
1	93	13
1	93	17
1	93	18
1	93	19
1	93	20
1	93	21
1	93	23
1	93	24
1	94	8
1	94	9
1	94	11
1	94	12
1	94	13
1	94	15
1	94	16
1	94	17
1	94	18
1	94	21
1	94	22
1	94	23
1	94	24
1	95	1
1	95	2
1	95	3
1	95	4
1	95	5
1	95	10
1	95	11
1	95	12
1	95	14
1	95	15
1	95	17
1	95	18
1	95	19
1	95	20
1	95	22
1	96	3
1	96	4
1	96	6
1	96	9
1	96	10
1	96	12
1	96	14
1	96	16
1	96	17
1	96	18
1	96	19
1	96	21
1	96	22
1	96	23
1	96	24
1	97	3
1	97	4
1	97	6
1	97	10
1	97	12
1	97	13
1	97	14
1	97	15
1	97	17
1	97	19
1	97	20
1	97	22
1	97	23
1	97	24
1	97	25
1	98	1
1	98	2
1	98	5
1	98	6
1	98	8
1	98	10
1	98	11
1	98	15
1	98	17
1	98	18
1	98	20
1	98	22
1	98	23
1	98	24
1	98	25
1	99	1
1	99	2
1	99	3
1	99	4
1	99	7
1	99	10
1	99	11
1	99	13
1	99	14
1	99	16
1	99	17
1	99	20
1	99	21
1	99	24
1	99	25
1	100	1
1	100	3
1	100	4
1	100	8
1	100	9
1	100	10
1	100	11
1	100	12
1	100	13
1	100	14
1	100	16
1	100	17
1	100	22
1	100	23
1	100	25
1	101	1
1	101	3
1	101	6
1	101	7
1	101	9
1	101	10
1	101	13
1	101	14
1	101	16
1	101	17
1	101	19
1	101	20
1	101	21
1	101	23
1	101	24
1	102	1
1	102	2
1	102	3
1	102	4
1	102	7
1	102	9
1	102	10
1	102	11
1	102	12
1	102	18
1	102	19
1	102	21
1	102	22
1	102	23
1	102	25
1	103	1
1	103	2
1	103	3
1	103	4
1	103	5
1	103	7
1	103	8
1	103	10
1	103	11
1	103	16
1	103	17
1	103	18
1	103	22
1	103	23
1	103	25
1	104	5
1	104	6
1	104	7
1	104	10
1	104	11
1	104	13
1	104	14
1	104	15
1	104	16
1	104	18
1	104	19
1	104	21
1	104	22
1	104	24
1	104	25
1	105	4
1	105	6
1	105	7
1	105	8
1	105	9
1	105	10
1	105	11
1	105	12
1	105	13
1	105	15
1	105	17
1	105	19
1	105	21
1	105	22
1	105	25
1	106	1
1	106	2
1	106	3
1	106	4
1	106	5
1	106	6
1	106	10
1	106	12
1	106	13
1	106	14
1	106	15
1	106	17
1	106	22
1	106	23
1	106	25
1	107	1
1	107	3
1	107	4
1	107	6
1	107	7
1	107	8
1	107	9
1	107	11
1	107	12
1	107	15
1	107	17
1	107	18
1	107	21
1	107	24
1	107	25
1	108	1
1	108	2
1	108	4
1	108	7
1	108	8
1	108	9
1	108	11
1	108	12
1	108	14
1	108	15
1	108	16
1	108	18
1	108	22
1	108	23
1	108	25
1	109	1
1	109	3
1	109	5
1	109	7
1	109	9
1	109	11
1	109	12
1	109	13
1	109	16
1	109	18
1	109	20
1	109	21
1	109	23
1	109	24
1	109	25
1	110	1
1	110	3
1	110	4
1	110	5
1	110	6
1	110	12
1	110	13
1	110	14
1	110	17
1	110	19
1	110	20
1	110	21
1	110	22
1	110	23
1	110	25
1	111	1
1	111	5
1	111	6
1	111	10
1	111	11
1	111	12
1	111	13
1	111	15
1	111	17
1	111	18
1	111	19
1	111	21
1	111	22
1	111	24
1	111	25
1	112	1
1	112	2
1	112	3
1	112	4
1	112	6
1	112	10
1	112	11
1	112	14
1	112	15
1	112	17
1	112	18
1	112	19
1	112	20
1	112	21
1	112	23
1	113	1
1	113	2
1	113	4
1	113	5
1	113	6
1	113	8
1	113	11
1	113	12
1	113	13
1	113	14
1	113	19
1	113	20
1	113	21
1	113	24
1	113	25
1	114	1
1	114	2
1	114	3
1	114	6
1	114	7
1	114	8
1	114	9
1	114	10
1	114	11
1	114	14
1	114	20
1	114	21
1	114	22
1	114	24
1	114	25
1	115	1
1	115	4
1	115	5
1	115	6
1	115	7
1	115	9
1	115	11
1	115	12
1	115	13
1	115	16
1	115	17
1	115	18
1	115	20
1	115	21
1	115	25
1	116	1
1	116	2
1	116	9
1	116	10
1	116	11
1	116	12
1	116	13
1	116	14
1	116	16
1	116	18
1	116	19
1	116	20
1	116	21
1	116	23
1	116	25
1	117	5
1	117	6
1	117	7
1	117	9
1	117	10
1	117	11
1	117	12
1	117	13
1	117	14
1	117	15
1	117	17
1	117	18
1	117	20
1	117	23
1	117	25
1	118	2
1	118	4
1	118	5
1	118	6
1	118	8
1	118	12
1	118	13
1	118	14
1	118	15
1	118	18
1	118	19
1	118	21
1	118	22
1	118	23
1	118	24
1	119	1
1	119	4
1	119	6
1	119	8
1	119	9
1	119	10
1	119	11
1	119	15
1	119	17
1	119	18
1	119	20
1	119	21
1	119	22
1	119	23
1	119	24
1	120	1
1	120	3
1	120	5
1	120	7
1	120	8
1	120	11
1	120	12
1	120	13
1	120	15
1	120	16
1	120	18
1	120	19
1	120	20
1	120	21
1	120	24
1	121	1
1	121	2
1	121	4
1	121	5
1	121	7
1	121	9
1	121	10
1	121	11
1	121	12
1	121	16
1	121	17
1	121	18
1	121	23
1	121	24
1	121	25
1	122	1
1	122	2
1	122	4
1	122	5
1	122	8
1	122	9
1	122	10
1	122	13
1	122	15
1	122	17
1	122	18
1	122	20
1	122	22
1	122	23
1	122	25
1	123	4
1	123	5
1	123	6
1	123	7
1	123	11
1	123	12
1	123	13
1	123	17
1	123	18
1	123	19
1	123	20
1	123	21
1	123	22
1	123	23
1	123	24
1	124	2
1	124	3
1	124	4
1	124	6
1	124	7
1	124	9
1	124	14
1	124	15
1	124	16
1	124	18
1	124	19
1	124	20
1	124	21
1	124	24
1	124	25
1	125	2
1	125	3
1	125	4
1	125	6
1	125	7
1	125	9
1	125	10
1	125	11
1	125	12
1	125	15
1	125	16
1	125	21
1	125	22
1	125	24
1	125	25
1	126	1
1	126	2
1	126	3
1	126	4
1	126	6
1	126	7
1	126	8
1	126	13
1	126	14
1	126	16
1	126	18
1	126	21
1	126	22
1	126	24
1	126	25
1	127	1
1	127	2
1	127	3
1	127	4
1	127	5
1	127	7
1	127	10
1	127	11
1	127	12
1	127	13
1	127	18
1	127	19
1	127	22
1	127	23
1	127	25
1	128	2
1	128	3
1	128	4
1	128	6
1	128	11
1	128	13
1	128	14
1	128	15
1	128	16
1	128	17
1	128	19
1	128	20
1	128	21
1	128	23
1	128	25
1	129	2
1	129	5
1	129	6
1	129	7
1	129	9
1	129	11
1	129	13
1	129	15
1	129	18
1	129	19
1	129	20
1	129	21
1	129	22
1	129	23
1	129	25
1	130	2
1	130	3
1	130	4
1	130	5
1	130	6
1	130	9
1	130	10
1	130	12
1	130	13
1	130	15
1	130	17
1	130	19
1	130	23
1	130	24
1	130	25
1	131	2
1	131	4
1	131	5
1	131	6
1	131	7
1	131	8
1	131	11
1	131	12
1	131	13
1	131	15
1	131	19
1	131	20
1	131	22
1	131	23
1	131	25
1	132	1
1	132	3
1	132	4
1	132	5
1	132	7
1	132	9
1	132	10
1	132	11
1	132	14
1	132	15
1	132	16
1	132	17
1	132	22
1	132	23
1	132	25
1	133	1
1	133	3
1	133	4
1	133	5
1	133	8
1	133	9
1	133	11
1	133	13
1	133	15
1	133	18
1	133	19
1	133	20
1	133	21
1	133	22
1	133	23
1	134	1
1	134	3
1	134	5
1	134	7
1	134	8
1	134	10
1	134	11
1	134	12
1	134	13
1	134	14
1	134	16
1	134	17
1	134	19
1	134	22
1	134	25
1	135	1
1	135	2
1	135	5
1	135	7
1	135	8
1	135	10
1	135	13
1	135	14
1	135	15
1	135	18
1	135	19
1	135	20
1	135	21
1	135	22
1	135	25
1	136	1
1	136	2
1	136	3
1	136	5
1	136	6
1	136	9
1	136	12
1	136	13
1	136	14
1	136	15
1	136	17
1	136	21
1	136	22
1	136	23
1	136	24
1	137	2
1	137	6
1	137	8
1	137	9
1	137	10
1	137	11
1	137	12
1	137	13
1	137	16
1	137	17
1	137	18
1	137	19
1	137	20
1	137	21
1	137	25
1	138	2
1	138	3
1	138	4
1	138	5
1	138	7
1	138	8
1	138	11
1	138	13
1	138	15
1	138	16
1	138	17
1	138	21
1	138	22
1	138	24
1	138	25
1	139	1
1	139	2
1	139	7
1	139	9
1	139	12
1	139	14
1	139	15
1	139	16
1	139	17
1	139	18
1	139	19
1	139	21
1	139	22
1	139	23
1	139	24
1	140	1
1	140	2
1	140	3
1	140	6
1	140	9
1	140	10
1	140	12
1	140	13
1	140	15
1	140	18
1	140	19
1	140	20
1	140	22
1	140	24
1	140	25
1	141	1
1	141	3
1	141	7
1	141	8
1	141	9
1	141	10
1	141	12
1	141	13
1	141	16
1	141	17
1	141	18
1	141	19
1	141	20
1	141	24
1	141	25
1	142	1
1	142	2
1	142	4
1	142	5
1	142	6
1	142	7
1	142	9
1	142	15
1	142	16
1	142	17
1	142	18
1	142	19
1	142	22
1	142	23
1	142	24
1	143	1
1	143	2
1	143	8
1	143	9
1	143	11
1	143	13
1	143	15
1	143	16
1	143	17
1	143	19
1	143	21
1	143	22
1	143	23
1	143	24
1	143	25
1	144	1
1	144	2
1	144	4
1	144	7
1	144	9
1	144	11
1	144	12
1	144	14
1	144	17
1	144	19
1	144	20
1	144	21
1	144	22
1	144	24
1	144	25
1	145	1
1	145	2
1	145	3
1	145	9
1	145	10
1	145	11
1	145	13
1	145	14
1	145	15
1	145	17
1	145	18
1	145	20
1	145	22
1	145	24
1	145	25
1	146	1
1	146	2
1	146	5
1	146	8
1	146	10
1	146	11
1	146	12
1	146	13
1	146	14
1	146	16
1	146	17
1	146	22
1	146	23
1	146	24
1	146	25
1	147	1
1	147	2
1	147	4
1	147	5
1	147	6
1	147	10
1	147	11
1	147	12
1	147	13
1	147	16
1	147	19
1	147	21
1	147	22
1	147	23
1	147	25
1	148	1
1	148	2
1	148	4
1	148	5
1	148	8
1	148	9
1	148	12
1	148	13
1	148	16
1	148	17
1	148	20
1	148	21
1	148	22
1	148	24
1	148	25
1	149	2
1	149	5
1	149	7
1	149	9
1	149	10
1	149	13
1	149	15
1	149	16
1	149	17
1	149	18
1	149	19
1	149	20
1	149	23
1	149	24
1	149	25
1	150	1
1	150	3
1	150	5
1	150	6
1	150	7
1	150	8
1	150	9
1	150	11
1	150	14
1	150	19
1	150	21
1	150	22
1	150	23
1	150	24
1	150	25
1	151	3
1	151	4
1	151	5
1	151	7
1	151	9
1	151	10
1	151	11
1	151	12
1	151	13
1	151	14
1	151	16
1	151	18
1	151	20
1	151	23
1	151	24
1	152	3
1	152	4
1	152	5
1	152	6
1	152	7
1	152	8
1	152	13
1	152	15
1	152	17
1	152	19
1	152	20
1	152	22
1	152	23
1	152	24
1	152	25
1	153	1
1	153	2
1	153	4
1	153	5
1	153	8
1	153	11
1	153	12
1	153	13
1	153	17
1	153	18
1	153	20
1	153	21
1	153	23
1	153	24
1	153	25
1	154	1
1	154	2
1	154	3
1	154	5
1	154	6
1	154	9
1	154	10
1	154	11
1	154	13
1	154	14
1	154	15
1	154	16
1	154	18
1	154	23
1	154	24
1	155	2
1	155	4
1	155	5
1	155	8
1	155	10
1	155	11
1	155	14
1	155	15
1	155	16
1	155	18
1	155	19
1	155	20
1	155	21
1	155	22
1	155	24
1	156	1
1	156	3
1	156	4
1	156	8
1	156	9
1	156	10
1	156	11
1	156	12
1	156	13
1	156	14
1	156	15
1	156	19
1	156	20
1	156	22
1	156	23
1	157	1
1	157	2
1	157	4
1	157	6
1	157	7
1	157	9
1	157	10
1	157	12
1	157	14
1	157	16
1	157	18
1	157	19
1	157	21
1	157	24
1	157	25
1	158	2
1	158	7
1	158	8
1	158	9
1	158	10
1	158	11
1	158	12
1	158	15
1	158	16
1	158	17
1	158	18
1	158	19
1	158	20
1	158	22
1	158	23
1	159	1
1	159	2
1	159	3
1	159	4
1	159	5
1	159	6
1	159	8
1	159	10
1	159	11
1	159	14
1	159	15
1	159	17
1	159	20
1	159	24
1	159	25
1	160	1
1	160	3
1	160	4
1	160	9
1	160	10
1	160	11
1	160	12
1	160	14
1	160	15
1	160	16
1	160	17
1	160	19
1	160	20
1	160	21
1	160	24
1	161	1
1	161	5
1	161	8
1	161	11
1	161	13
1	161	15
1	161	16
1	161	17
1	161	18
1	161	20
1	161	21
1	161	22
1	161	23
1	161	24
1	161	25
1	162	1
1	162	2
1	162	3
1	162	4
1	162	5
1	162	6
1	162	8
1	162	11
1	162	12
1	162	13
1	162	16
1	162	18
1	162	20
1	162	23
1	162	24
1	163	1
1	163	2
1	163	3
1	163	5
1	163	6
1	163	7
1	163	9
1	163	13
1	163	14
1	163	15
1	163	20
1	163	21
1	163	23
1	163	24
1	163	25
1	164	1
1	164	2
1	164	3
1	164	5
1	164	6
1	164	8
1	164	10
1	164	11
1	164	14
1	164	15
1	164	18
1	164	21
1	164	22
1	164	23
1	164	24
1	165	1
1	165	2
1	165	4
1	165	6
1	165	8
1	165	9
1	165	12
1	165	13
1	165	14
1	165	15
1	165	17
1	165	18
1	165	19
1	165	22
1	165	25
1	166	2
1	166	3
1	166	4
1	166	8
1	166	9
1	166	10
1	166	13
1	166	14
1	166	15
1	166	18
1	166	19
1	166	20
1	166	21
1	166	22
1	166	23
1	167	1
1	167	2
1	167	3
1	167	6
1	167	8
1	167	9
1	167	10
1	167	13
1	167	14
1	167	16
1	167	18
1	167	19
1	167	22
1	167	23
1	167	24
1	168	1
1	168	2
1	168	3
1	168	4
1	168	7
1	168	10
1	168	12
1	168	15
1	168	16
1	168	17
1	168	19
1	168	20
1	168	22
1	168	23
1	168	24
1	169	1
1	169	4
1	169	5
1	169	6
1	169	7
1	169	8
1	169	9
1	169	10
1	169	11
1	169	12
1	169	15
1	169	16
1	169	20
1	169	21
1	169	24
1	170	1
1	170	3
1	170	4
1	170	5
1	170	6
1	170	7
1	170	8
1	170	10
1	170	13
1	170	16
1	170	18
1	170	20
1	170	22
1	170	23
1	170	25
1	171	1
1	171	3
1	171	4
1	171	10
1	171	11
1	171	12
1	171	13
1	171	15
1	171	16
1	171	17
1	171	21
1	171	22
1	171	23
1	171	24
1	171	25
1	172	1
1	172	2
1	172	4
1	172	6
1	172	7
1	172	9
1	172	10
1	172	11
1	172	12
1	172	13
1	172	18
1	172	20
1	172	21
1	172	22
1	172	25
1	173	2
1	173	3
1	173	4
1	173	5
1	173	7
1	173	8
1	173	11
1	173	15
1	173	19
1	173	20
1	173	21
1	173	22
1	173	23
1	173	24
1	173	25
1	174	1
1	174	2
1	174	4
1	174	7
1	174	9
1	174	10
1	174	11
1	174	12
1	174	13
1	174	15
1	174	17
1	174	20
1	174	23
1	174	24
1	174	25
1	175	2
1	175	3
1	175	5
1	175	6
1	175	7
1	175	11
1	175	12
1	175	13
1	175	14
1	175	15
1	175	16
1	175	18
1	175	19
1	175	21
1	175	24
1	176	2
1	176	4
1	176	10
1	176	11
1	176	12
1	176	13
1	176	15
1	176	16
1	176	17
1	176	18
1	176	21
1	176	22
1	176	23
1	176	24
1	176	25
1	177	2
1	177	6
1	177	7
1	177	8
1	177	10
1	177	11
1	177	13
1	177	15
1	177	16
1	177	17
1	177	19
1	177	20
1	177	21
1	177	23
1	177	24
1	178	2
1	178	3
1	178	4
1	178	6
1	178	8
1	178	9
1	178	10
1	178	14
1	178	16
1	178	19
1	178	20
1	178	21
1	178	23
1	178	24
1	178	25
1	179	2
1	179	3
1	179	4
1	179	5
1	179	7
1	179	9
1	179	13
1	179	14
1	179	15
1	179	17
1	179	19
1	179	22
1	179	23
1	179	24
1	179	25
1	180	1
1	180	2
1	180	3
1	180	4
1	180	5
1	180	6
1	180	7
1	180	8
1	180	10
1	180	11
1	180	15
1	180	17
1	180	20
1	180	24
1	180	25
1	181	1
1	181	4
1	181	5
1	181	6
1	181	7
1	181	8
1	181	14
1	181	15
1	181	16
1	181	17
1	181	19
1	181	20
1	181	21
1	181	22
1	181	23
1	182	2
1	182	3
1	182	4
1	182	7
1	182	8
1	182	9
1	182	11
1	182	13
1	182	14
1	182	17
1	182	19
1	182	21
1	182	22
1	182	23
1	182	25
1	183	2
1	183	4
1	183	6
1	183	7
1	183	8
1	183	11
1	183	13
1	183	14
1	183	16
1	183	19
1	183	20
1	183	21
1	183	23
1	183	24
1	183	25
1	184	1
1	184	3
1	184	7
1	184	8
1	184	9
1	184	10
1	184	11
1	184	15
1	184	16
1	184	17
1	184	18
1	184	19
1	184	21
1	184	23
1	184	25
1	185	1
1	185	2
1	185	4
1	185	6
1	185	7
1	185	8
1	185	9
1	185	11
1	185	12
1	185	15
1	185	17
1	185	19
1	185	20
1	185	23
1	185	25
1	186	2
1	186	4
1	186	5
1	186	6
1	186	11
1	186	12
1	186	13
1	186	16
1	186	17
1	186	18
1	186	19
1	186	22
1	186	23
1	186	24
1	186	25
1	187	1
1	187	3
1	187	11
1	187	12
1	187	13
1	187	15
1	187	16
1	187	17
1	187	18
1	187	19
1	187	21
1	187	22
1	187	23
1	187	24
1	187	25
1	188	2
1	188	3
1	188	5
1	188	8
1	188	10
1	188	11
1	188	13
1	188	16
1	188	19
1	188	20
1	188	21
1	188	22
1	188	23
1	188	24
1	188	25
1	189	1
1	189	2
1	189	4
1	189	5
1	189	6
1	189	7
1	189	9
1	189	13
1	189	16
1	189	18
1	189	19
1	189	20
1	189	22
1	189	23
1	189	24
1	190	1
1	190	3
1	190	4
1	190	5
1	190	7
1	190	8
1	190	11
1	190	13
1	190	14
1	190	15
1	190	16
1	190	18
1	190	19
1	190	23
1	190	24
1	191	2
1	191	5
1	191	8
1	191	9
1	191	10
1	191	12
1	191	13
1	191	15
1	191	17
1	191	18
1	191	19
1	191	20
1	191	21
1	191	22
1	191	23
1	192	1
1	192	2
1	192	3
1	192	4
1	192	5
1	192	6
1	192	11
1	192	13
1	192	14
1	192	15
1	192	16
1	192	21
1	192	22
1	192	23
1	192	24
1	193	1
1	193	2
1	193	3
1	193	4
1	193	5
1	193	8
1	193	9
1	193	10
1	193	14
1	193	15
1	193	16
1	193	19
1	193	20
1	193	21
1	193	25
1	194	2
1	194	7
1	194	8
1	194	9
1	194	10
1	194	12
1	194	13
1	194	14
1	194	15
1	194	17
1	194	18
1	194	21
1	194	22
1	194	23
1	194	25
1	195	2
1	195	3
1	195	4
1	195	6
1	195	7
1	195	8
1	195	9
1	195	11
1	195	12
1	195	14
1	195	17
1	195	18
1	195	19
1	195	22
1	195	23
1	196	2
1	196	3
1	196	4
1	196	5
1	196	10
1	196	14
1	196	15
1	196	16
1	196	17
1	196	19
1	196	20
1	196	22
1	196	23
1	196	24
1	196	25
1	197	3
1	197	4
1	197	5
1	197	6
1	197	7
1	197	8
1	197	9
1	197	10
1	197	12
1	197	13
1	197	18
1	197	20
1	197	21
1	197	22
1	197	23
1	198	1
1	198	2
1	198	4
1	198	5
1	198	6
1	198	7
1	198	13
1	198	14
1	198	15
1	198	16
1	198	17
1	198	18
1	198	20
1	198	21
1	198	25
1	199	1
1	199	2
1	199	3
1	199	4
1	199	5
1	199	6
1	199	9
1	199	11
1	199	12
1	199	15
1	199	19
1	199	20
1	199	21
1	199	22
1	199	23
1	200	1
1	200	2
1	200	4
1	200	5
1	200	8
1	200	9
1	200	11
1	200	12
1	200	13
1	200	14
1	200	15
1	200	16
1	200	21
1	200	23
1	200	24
1	201	1
1	201	2
1	201	4
1	201	5
1	201	8
1	201	9
1	201	10
1	201	11
1	201	12
1	201	13
1	201	14
1	201	15
1	201	19
1	201	20
1	201	22
1	202	1
1	202	3
1	202	5
1	202	10
1	202	11
1	202	13
1	202	14
1	202	16
1	202	17
1	202	18
1	202	19
1	202	21
1	202	22
1	202	23
1	202	24
1	203	1
1	203	2
1	203	3
1	203	4
1	203	5
1	203	6
1	203	7
1	203	12
1	203	13
1	203	14
1	203	17
1	203	18
1	203	23
1	203	24
1	203	25
1	204	2
1	204	3
1	204	4
1	204	5
1	204	7
1	204	8
1	204	11
1	204	14
1	204	15
1	204	16
1	204	17
1	204	22
1	204	23
1	204	24
1	204	25
1	205	2
1	205	3
1	205	4
1	205	9
1	205	10
1	205	11
1	205	12
1	205	14
1	205	15
1	205	16
1	205	17
1	205	18
1	205	21
1	205	22
1	205	25
1	206	2
1	206	3
1	206	5
1	206	8
1	206	9
1	206	11
1	206	12
1	206	13
1	206	14
1	206	15
1	206	16
1	206	17
1	206	20
1	206	21
1	206	22
1	207	1
1	207	2
1	207	3
1	207	4
1	207	6
1	207	9
1	207	10
1	207	12
1	207	13
1	207	14
1	207	15
1	207	17
1	207	19
1	207	20
1	207	22
1	208	1
1	208	3
1	208	4
1	208	6
1	208	7
1	208	9
1	208	10
1	208	11
1	208	12
1	208	14
1	208	15
1	208	16
1	208	19
1	208	23
1	208	24
1	209	1
1	209	3
1	209	5
1	209	6
1	209	7
1	209	9
1	209	10
1	209	14
1	209	15
1	209	18
1	209	19
1	209	21
1	209	22
1	209	24
1	209	25
1	210	3
1	210	5
1	210	7
1	210	9
1	210	10
1	210	11
1	210	13
1	210	14
1	210	15
1	210	16
1	210	18
1	210	21
1	210	22
1	210	23
1	210	24
1	211	1
1	211	2
1	211	4
1	211	6
1	211	8
1	211	10
1	211	11
1	211	12
1	211	14
1	211	16
1	211	17
1	211	18
1	211	22
1	211	24
1	211	25
1	212	1
1	212	3
1	212	4
1	212	6
1	212	8
1	212	9
1	212	10
1	212	11
1	212	12
1	212	14
1	212	16
1	212	19
1	212	20
1	212	22
1	212	23
1	213	1
1	213	3
1	213	4
1	213	5
1	213	8
1	213	9
1	213	10
1	213	11
1	213	16
1	213	18
1	213	19
1	213	21
1	213	23
1	213	24
1	213	25
1	214	1
1	214	2
1	214	3
1	214	4
1	214	9
1	214	11
1	214	13
1	214	14
1	214	15
1	214	18
1	214	19
1	214	20
1	214	22
1	214	24
1	214	25
1	215	1
1	215	3
1	215	4
1	215	5
1	215	7
1	215	9
1	215	11
1	215	12
1	215	14
1	215	15
1	215	17
1	215	18
1	215	19
1	215	23
1	215	25
1	216	2
1	216	3
1	216	4
1	216	5
1	216	6
1	216	7
1	216	9
1	216	10
1	216	11
1	216	13
1	216	17
1	216	19
1	216	21
1	216	24
1	216	25
1	217	2
1	217	3
1	217	4
1	217	5
1	217	6
1	217	7
1	217	9
1	217	10
1	217	11
1	217	12
1	217	16
1	217	17
1	217	19
1	217	21
1	217	25
1	218	2
1	218	5
1	218	7
1	218	8
1	218	11
1	218	12
1	218	13
1	218	14
1	218	15
1	218	16
1	218	17
1	218	20
1	218	21
1	218	22
1	218	25
1	219	2
1	219	3
1	219	6
1	219	8
1	219	9
1	219	11
1	219	14
1	219	16
1	219	17
1	219	18
1	219	19
1	219	22
1	219	23
1	219	24
1	219	25
1	220	5
1	220	9
1	220	10
1	220	12
1	220	13
1	220	14
1	220	15
1	220	16
1	220	17
1	220	18
1	220	20
1	220	21
1	220	23
1	220	24
1	220	25
1	221	1
1	221	2
1	221	3
1	221	6
1	221	7
1	221	8
1	221	10
1	221	12
1	221	16
1	221	17
1	221	19
1	221	20
1	221	21
1	221	23
1	221	25
1	222	1
1	222	3
1	222	4
1	222	5
1	222	6
1	222	7
1	222	8
1	222	9
1	222	12
1	222	15
1	222	18
1	222	21
1	222	22
1	222	23
1	222	24
1	223	2
1	223	4
1	223	7
1	223	9
1	223	10
1	223	11
1	223	12
1	223	13
1	223	14
1	223	16
1	223	20
1	223	21
1	223	22
1	223	23
1	223	24
1	224	4
1	224	6
1	224	8
1	224	9
1	224	10
1	224	11
1	224	12
1	224	13
1	224	15
1	224	18
1	224	19
1	224	20
1	224	21
1	224	23
1	224	24
1	225	1
1	225	2
1	225	3
1	225	5
1	225	7
1	225	8
1	225	13
1	225	14
1	225	15
1	225	18
1	225	19
1	225	20
1	225	22
1	225	23
1	225	25
1	226	4
1	226	5
1	226	8
1	226	10
1	226	11
1	226	13
1	226	14
1	226	15
1	226	16
1	226	17
1	226	18
1	226	19
1	226	20
1	226	21
1	226	25
1	227	1
1	227	5
1	227	7
1	227	8
1	227	9
1	227	10
1	227	12
1	227	14
1	227	15
1	227	17
1	227	18
1	227	19
1	227	20
1	227	21
1	227	22
1	228	2
1	228	4
1	228	10
1	228	11
1	228	12
1	228	13
1	228	14
1	228	15
1	228	16
1	228	17
1	228	18
1	228	19
1	228	20
1	228	24
1	228	25
1	229	2
1	229	6
1	229	8
1	229	9
1	229	10
1	229	11
1	229	12
1	229	13
1	229	14
1	229	15
1	229	16
1	229	17
1	229	20
1	229	23
1	229	25
1	230	1
1	230	2
1	230	3
1	230	4
1	230	5
1	230	6
1	230	8
1	230	10
1	230	11
1	230	13
1	230	14
1	230	15
1	230	17
1	230	22
1	230	24
1	231	1
1	231	2
1	231	5
1	231	6
1	231	7
1	231	10
1	231	12
1	231	15
1	231	16
1	231	17
1	231	18
1	231	19
1	231	21
1	231	24
1	231	25
1	232	4
1	232	5
1	232	6
1	232	9
1	232	11
1	232	12
1	232	13
1	232	14
1	232	16
1	232	17
1	232	18
1	232	21
1	232	23
1	232	24
1	232	25
1	233	1
1	233	2
1	233	3
1	233	4
1	233	5
1	233	6
1	233	7
1	233	8
1	233	9
1	233	12
1	233	13
1	233	14
1	233	17
1	233	19
1	233	21
1	234	1
1	234	2
1	234	3
1	234	4
1	234	5
1	234	9
1	234	11
1	234	12
1	234	13
1	234	14
1	234	15
1	234	17
1	234	21
1	234	22
1	234	24
1	235	1
1	235	8
1	235	10
1	235	12
1	235	13
1	235	14
1	235	15
1	235	16
1	235	17
1	235	18
1	235	19
1	235	21
1	235	23
1	235	24
1	235	25
1	236	1
1	236	3
1	236	4
1	236	5
1	236	7
1	236	8
1	236	9
1	236	12
1	236	13
1	236	15
1	236	16
1	236	21
1	236	22
1	236	23
1	236	25
1	237	4
1	237	5
1	237	6
1	237	7
1	237	9
1	237	12
1	237	13
1	237	15
1	237	16
1	237	18
1	237	19
1	237	20
1	237	21
1	237	22
1	237	23
1	238	1
1	238	3
1	238	4
1	238	6
1	238	11
1	238	12
1	238	13
1	238	14
1	238	15
1	238	17
1	238	19
1	238	20
1	238	21
1	238	23
1	238	24
1	239	1
1	239	3
1	239	5
1	239	6
1	239	7
1	239	9
1	239	10
1	239	13
1	239	14
1	239	15
1	239	16
1	239	19
1	239	22
1	239	23
1	239	25
1	240	1
1	240	2
1	240	4
1	240	9
1	240	10
1	240	11
1	240	13
1	240	14
1	240	15
1	240	16
1	240	18
1	240	19
1	240	21
1	240	22
1	240	23
1	241	3
1	241	4
1	241	5
1	241	8
1	241	9
1	241	12
1	241	13
1	241	14
1	241	15
1	241	17
1	241	20
1	241	21
1	241	23
1	241	24
1	241	25
1	242	2
1	242	5
1	242	6
1	242	8
1	242	9
1	242	13
1	242	14
1	242	15
1	242	16
1	242	17
1	242	18
1	242	19
1	242	21
1	242	22
1	242	23
1	243	1
1	243	2
1	243	3
1	243	4
1	243	5
1	243	7
1	243	12
1	243	13
1	243	16
1	243	17
1	243	18
1	243	20
1	243	21
1	243	23
1	243	25
1	244	3
1	244	5
1	244	6
1	244	7
1	244	9
1	244	10
1	244	11
1	244	12
1	244	14
1	244	15
1	244	18
1	244	20
1	244	21
1	244	22
1	244	24
1	245	1
1	245	2
1	245	6
1	245	7
1	245	9
1	245	10
1	245	11
1	245	12
1	245	14
1	245	15
1	245	16
1	245	18
1	245	19
1	245	24
1	245	25
1	246	1
1	246	4
1	246	5
1	246	7
1	246	8
1	246	9
1	246	10
1	246	12
1	246	13
1	246	15
1	246	17
1	246	18
1	246	21
1	246	24
1	246	25
1	247	1
1	247	2
1	247	3
1	247	4
1	247	7
1	247	8
1	247	9
1	247	14
1	247	15
1	247	16
1	247	17
1	247	19
1	247	22
1	247	23
1	247	25
1	248	1
1	248	2
1	248	5
1	248	8
1	248	9
1	248	10
1	248	11
1	248	12
1	248	13
1	248	15
1	248	16
1	248	19
1	248	20
1	248	21
1	248	25
1	249	4
1	249	5
1	249	7
1	249	8
1	249	9
1	249	10
1	249	12
1	249	14
1	249	15
1	249	17
1	249	18
1	249	21
1	249	22
1	249	23
1	249	25
1	250	1
1	250	2
1	250	3
1	250	5
1	250	9
1	250	10
1	250	12
1	250	13
1	250	15
1	250	16
1	250	17
1	250	18
1	250	19
1	250	21
1	250	23
1	251	3
1	251	4
1	251	5
1	251	6
1	251	9
1	251	10
1	251	13
1	251	15
1	251	16
1	251	18
1	251	19
1	251	21
1	251	22
1	251	23
1	251	25
1	252	2
1	252	3
1	252	4
1	252	6
1	252	8
1	252	11
1	252	14
1	252	15
1	252	17
1	252	18
1	252	19
1	252	22
1	252	23
1	252	24
1	252	25
1	253	1
1	253	4
1	253	5
1	253	6
1	253	7
1	253	8
1	253	11
1	253	12
1	253	13
1	253	15
1	253	18
1	253	19
1	253	21
1	253	22
1	253	23
1	254	2
1	254	3
1	254	4
1	254	5
1	254	6
1	254	7
1	254	8
1	254	9
1	254	11
1	254	13
1	254	14
1	254	15
1	254	16
1	254	20
1	254	23
1	255	1
1	255	2
1	255	3
1	255	4
1	255	6
1	255	9
1	255	10
1	255	14
1	255	15
1	255	16
1	255	17
1	255	21
1	255	22
1	255	23
1	255	24
1	256	1
1	256	2
1	256	6
1	256	7
1	256	8
1	256	9
1	256	10
1	256	12
1	256	13
1	256	15
1	256	16
1	256	18
1	256	20
1	256	22
1	256	24
1	257	1
1	257	3
1	257	6
1	257	7
1	257	9
1	257	10
1	257	12
1	257	13
1	257	14
1	257	16
1	257	17
1	257	18
1	257	19
1	257	22
1	257	24
1	258	2
1	258	4
1	258	5
1	258	6
1	258	9
1	258	12
1	258	13
1	258	14
1	258	17
1	258	19
1	258	20
1	258	21
1	258	22
1	258	24
1	258	25
1	259	3
1	259	5
1	259	6
1	259	7
1	259	8
1	259	9
1	259	10
1	259	15
1	259	18
1	259	19
1	259	20
1	259	21
1	259	22
1	259	24
1	259	25
1	260	1
1	260	3
1	260	4
1	260	5
1	260	6
1	260	7
1	260	8
1	260	9
1	260	11
1	260	13
1	260	14
1	260	18
1	260	19
1	260	20
1	260	24
1	261	1
1	261	2
1	261	4
1	261	5
1	261	6
1	261	7
1	261	11
1	261	13
1	261	15
1	261	16
1	261	17
1	261	19
1	261	20
1	261	21
1	261	25
1	262	3
1	262	4
1	262	6
1	262	7
1	262	8
1	262	9
1	262	12
1	262	13
1	262	14
1	262	15
1	262	17
1	262	20
1	262	21
1	262	23
1	262	24
1	263	1
1	263	4
1	263	7
1	263	8
1	263	9
1	263	10
1	263	11
1	263	14
1	263	15
1	263	16
1	263	18
1	263	19
1	263	21
1	263	23
1	263	24
1	264	1
1	264	3
1	264	4
1	264	6
1	264	8
1	264	9
1	264	12
1	264	13
1	264	16
1	264	19
1	264	20
1	264	21
1	264	22
1	264	23
1	264	25
1	265	1
1	265	5
1	265	7
1	265	8
1	265	11
1	265	12
1	265	13
1	265	15
1	265	16
1	265	17
1	265	18
1	265	19
1	265	20
1	265	22
1	265	24
1	266	1
1	266	3
1	266	4
1	266	5
1	266	6
1	266	7
1	266	9
1	266	11
1	266	14
1	266	15
1	266	18
1	266	19
1	266	21
1	266	22
1	266	24
1	267	2
1	267	3
1	267	4
1	267	5
1	267	6
1	267	9
1	267	11
1	267	12
1	267	13
1	267	14
1	267	15
1	267	17
1	267	21
1	267	23
1	267	24
1	268	5
1	268	6
1	268	7
1	268	8
1	268	9
1	268	10
1	268	12
1	268	14
1	268	15
1	268	16
1	268	18
1	268	19
1	268	20
1	268	23
1	268	25
1	269	1
1	269	2
1	269	4
1	269	6
1	269	10
1	269	13
1	269	14
1	269	15
1	269	16
1	269	17
1	269	18
1	269	19
1	269	22
1	269	23
1	269	24
1	270	1
1	270	3
1	270	4
1	270	5
1	270	6
1	270	7
1	270	8
1	270	9
1	270	14
1	270	16
1	270	18
1	270	19
1	270	23
1	270	24
1	270	25
1	271	1
1	271	2
1	271	4
1	271	5
1	271	6
1	271	8
1	271	11
1	271	12
1	271	16
1	271	18
1	271	19
1	271	20
1	271	21
1	271	24
1	271	25
1	272	1
1	272	2
1	272	4
1	272	5
1	272	8
1	272	9
1	272	11
1	272	12
1	272	13
1	272	15
1	272	17
1	272	20
1	272	23
1	272	24
1	272	25
1	273	1
1	273	5
1	273	6
1	273	7
1	273	10
1	273	12
1	273	15
1	273	16
1	273	17
1	273	18
1	273	19
1	273	20
1	273	21
1	273	24
1	273	25
1	274	2
1	274	4
1	274	5
1	274	6
1	274	7
1	274	10
1	274	11
1	274	12
1	274	14
1	274	15
1	274	17
1	274	20
1	274	21
1	274	23
1	274	25
1	275	1
1	275	3
1	275	5
1	275	6
1	275	8
1	275	9
1	275	10
1	275	11
1	275	12
1	275	14
1	275	15
1	275	17
1	275	18
1	275	20
1	275	22
1	276	2
1	276	3
1	276	4
1	276	5
1	276	7
1	276	10
1	276	11
1	276	12
1	276	13
1	276	17
1	276	18
1	276	19
1	276	20
1	276	22
1	276	25
1	277	2
1	277	4
1	277	9
1	277	10
1	277	11
1	277	12
1	277	13
1	277	14
1	277	16
1	277	17
1	277	21
1	277	22
1	277	23
1	277	24
1	277	25
1	278	1
1	278	2
1	278	3
1	278	5
1	278	6
1	278	9
1	278	11
1	278	12
1	278	13
1	278	15
1	278	17
1	278	19
1	278	21
1	278	23
1	278	25
1	279	1
1	279	2
1	279	3
1	279	5
1	279	6
1	279	9
1	279	10
1	279	11
1	279	12
1	279	13
1	279	17
1	279	18
1	279	19
1	279	22
1	279	23
1	280	3
1	280	4
1	280	5
1	280	6
1	280	9
1	280	10
1	280	11
1	280	13
1	280	15
1	280	16
1	280	17
1	280	19
1	280	20
1	280	24
1	280	25
1	281	1
1	281	2
1	281	3
1	281	4
1	281	8
1	281	9
1	281	10
1	281	11
1	281	12
1	281	14
1	281	15
1	281	17
1	281	19
1	281	23
1	281	25
1	282	2
1	282	3
1	282	4
1	282	7
1	282	8
1	282	11
1	282	12
1	282	13
1	282	15
1	282	16
1	282	19
1	282	20
1	282	21
1	282	22
1	282	25
1	283	1
1	283	2
1	283	4
1	283	6
1	283	8
1	283	9
1	283	10
1	283	11
1	283	12
1	283	13
1	283	19
1	283	20
1	283	22
1	283	23
1	283	24
1	284	1
1	284	3
1	284	5
1	284	6
1	284	7
1	284	11
1	284	12
1	284	13
1	284	15
1	284	17
1	284	19
1	284	21
1	284	22
1	284	23
1	284	25
1	285	1
1	285	4
1	285	5
1	285	8
1	285	9
1	285	10
1	285	11
1	285	12
1	285	13
1	285	14
1	285	15
1	285	16
1	285	19
1	285	22
1	285	23
1	286	1
1	286	2
1	286	3
1	286	4
1	286	7
1	286	9
1	286	10
1	286	11
1	286	12
1	286	13
1	286	19
1	286	21
1	286	23
1	286	24
1	286	25
1	287	2
1	287	5
1	287	6
1	287	7
1	287	10
1	287	12
1	287	13
1	287	15
1	287	16
1	287	17
1	287	18
1	287	21
1	287	22
1	287	23
1	287	25
1	288	1
1	288	2
1	288	3
1	288	4
1	288	6
1	288	9
1	288	10
1	288	12
1	288	13
1	288	14
1	288	15
1	288	18
1	288	19
1	288	24
1	288	25
1	289	1
1	289	2
1	289	3
1	289	4
1	289	6
1	289	8
1	289	9
1	289	10
1	289	12
1	289	14
1	289	15
1	289	17
1	289	19
1	289	22
1	289	24
1	290	1
1	290	2
1	290	5
1	290	6
1	290	7
1	290	9
1	290	11
1	290	12
1	290	13
1	290	14
1	290	17
1	290	20
1	290	21
1	290	22
1	290	23
1	291	1
1	291	2
1	291	5
1	291	7
1	291	8
1	291	10
1	291	11
1	291	12
1	291	13
1	291	14
1	291	15
1	291	17
1	291	20
1	291	23
1	291	24
1	292	2
1	292	3
1	292	5
1	292	7
1	292	8
1	292	9
1	292	11
1	292	12
1	292	13
1	292	16
1	292	17
1	292	21
1	292	22
1	292	24
1	292	25
1	293	1
1	293	2
1	293	3
1	293	6
1	293	9
1	293	12
1	293	13
1	293	14
1	293	15
1	293	18
1	293	19
1	293	22
1	293	23
1	293	24
1	293	25
1	294	1
1	294	2
1	294	3
1	294	4
1	294	5
1	294	7
1	294	8
1	294	11
1	294	12
1	294	15
1	294	16
1	294	20
1	294	23
1	294	24
1	294	25
1	295	2
1	295	3
1	295	4
1	295	6
1	295	10
1	295	13
1	295	15
1	295	16
1	295	17
1	295	18
1	295	19
1	295	21
1	295	23
1	295	24
1	295	25
1	296	2
1	296	3
1	296	6
1	296	7
1	296	8
1	296	11
1	296	12
1	296	14
1	296	15
1	296	16
1	296	17
1	296	18
1	296	19
1	296	22
1	296	25
1	297	1
1	297	4
1	297	7
1	297	8
1	297	9
1	297	10
1	297	12
1	297	14
1	297	15
1	297	16
1	297	21
1	297	22
1	297	23
1	297	24
1	297	25
1	298	1
1	298	3
1	298	4
1	298	6
1	298	7
1	298	8
1	298	11
1	298	12
1	298	13
1	298	14
1	298	15
1	298	16
1	298	21
1	298	22
1	298	24
1	299	3
1	299	5
1	299	6
1	299	7
1	299	8
1	299	10
1	299	13
1	299	17
1	299	18
1	299	19
1	299	20
1	299	21
1	299	22
1	299	23
1	299	24
1	300	3
1	300	4
1	300	7
1	300	8
1	300	9
1	300	11
1	300	12
1	300	15
1	300	17
1	300	19
1	300	20
1	300	21
1	300	22
1	300	23
1	300	25
1	301	2
1	301	3
1	301	8
1	301	9
1	301	11
1	301	12
1	301	13
1	301	14
1	301	15
1	301	17
1	301	18
1	301	19
1	301	20
1	301	22
1	301	23
1	302	2
1	302	4
1	302	5
1	302	6
1	302	9
1	302	10
1	302	11
1	302	12
1	302	14
1	302	15
1	302	16
1	302	18
1	302	20
1	302	22
1	302	25
1	303	2
1	303	3
1	303	4
1	303	6
1	303	8
1	303	12
1	303	15
1	303	16
1	303	17
1	303	18
1	303	20
1	303	21
1	303	22
1	303	23
1	303	24
1	304	1
1	304	3
1	304	4
1	304	5
1	304	12
1	304	14
1	304	15
1	304	16
1	304	17
1	304	18
1	304	19
1	304	20
1	304	21
1	304	22
1	304	25
1	305	2
1	305	3
1	305	4
1	305	5
1	305	8
1	305	10
1	305	11
1	305	12
1	305	13
1	305	18
1	305	20
1	305	21
1	305	22
1	305	24
1	305	25
1	306	1
1	306	2
1	306	4
1	306	5
1	306	8
1	306	11
1	306	12
1	306	13
1	306	14
1	306	15
1	306	16
1	306	18
1	306	19
1	306	20
1	306	25
1	307	1
1	307	3
1	307	4
1	307	6
1	307	9
1	307	10
1	307	12
1	307	14
1	307	15
1	307	17
1	307	19
1	307	20
1	307	21
1	307	23
1	307	24
1	308	1
1	308	2
1	308	4
1	308	5
1	308	12
1	308	13
1	308	15
1	308	16
1	308	18
1	308	19
1	308	21
1	308	22
1	308	23
1	308	24
1	308	25
1	309	1
1	309	2
1	309	3
1	309	4
1	309	8
1	309	9
1	309	10
1	309	13
1	309	14
1	309	16
1	309	17
1	309	20
1	309	21
1	309	22
1	309	24
1	310	2
1	310	3
1	310	5
1	310	9
1	310	10
1	310	11
1	310	14
1	310	15
1	310	16
1	310	17
1	310	18
1	310	19
1	310	21
1	310	23
1	310	24
1	311	2
1	311	4
1	311	5
1	311	7
1	311	10
1	311	12
1	311	14
1	311	15
1	311	16
1	311	17
1	311	19
1	311	20
1	311	23
1	311	24
1	311	25
1	312	1
1	312	2
1	312	6
1	312	8
1	312	9
1	312	10
1	312	11
1	312	12
1	312	13
1	312	16
1	312	17
1	312	18
1	312	19
1	312	22
1	312	25
1	313	2
1	313	3
1	313	6
1	313	7
1	313	9
1	313	10
1	313	12
1	313	14
1	313	15
1	313	16
1	313	17
1	313	18
1	313	19
1	313	23
1	313	25
1	314	1
1	314	2
1	314	5
1	314	6
1	314	8
1	314	9
1	314	11
1	314	12
1	314	13
1	314	14
1	314	15
1	314	19
1	314	20
1	314	21
1	314	22
1	315	2
1	315	3
1	315	5
1	315	6
1	315	8
1	315	11
1	315	13
1	315	14
1	315	16
1	315	17
1	315	19
1	315	20
1	315	21
1	315	23
1	315	24
1	316	1
1	316	3
1	316	4
1	316	6
1	316	7
1	316	8
1	316	10
1	316	12
1	316	13
1	316	14
1	316	15
1	316	18
1	316	19
1	316	23
1	316	24
1	317	1
1	317	2
1	317	4
1	317	5
1	317	8
1	317	9
1	317	11
1	317	14
1	317	16
1	317	18
1	317	19
1	317	21
1	317	22
1	317	24
1	317	25
1	318	3
1	318	4
1	318	5
1	318	6
1	318	9
1	318	11
1	318	12
1	318	13
1	318	14
1	318	15
1	318	16
1	318	18
1	318	21
1	318	23
1	318	25
1	319	1
1	319	3
1	319	4
1	319	6
1	319	8
1	319	9
1	319	10
1	319	12
1	319	14
1	319	16
1	319	17
1	319	19
1	319	20
1	319	23
1	319	24
1	320	1
1	320	3
1	320	6
1	320	9
1	320	11
1	320	12
1	320	14
1	320	15
1	320	17
1	320	18
1	320	19
1	320	21
1	320	22
1	320	23
1	320	25
1	321	2
1	321	3
1	321	4
1	321	9
1	321	10
1	321	11
1	321	12
1	321	13
1	321	14
1	321	16
1	321	17
1	321	18
1	321	20
1	321	24
1	321	25
1	322	1
1	322	2
1	322	3
1	322	5
1	322	7
1	322	12
1	322	13
1	322	15
1	322	16
1	322	17
1	322	18
1	322	20
1	322	21
1	322	23
1	322	24
1	323	1
1	323	2
1	323	3
1	323	4
1	323	6
1	323	7
1	323	9
1	323	10
1	323	14
1	323	17
1	323	19
1	323	20
1	323	21
1	323	23
1	323	25
1	324	1
1	324	2
1	324	3
1	324	4
1	324	6
1	324	7
1	324	8
1	324	9
1	324	10
1	324	12
1	324	16
1	324	20
1	324	21
1	324	23
1	324	24
1	325	1
1	325	2
1	325	4
1	325	5
1	325	6
1	325	7
1	325	10
1	325	14
1	325	15
1	325	19
1	325	20
1	325	22
1	325	23
1	325	24
1	325	25
1	326	1
1	326	2
1	326	4
1	326	6
1	326	7
1	326	8
1	326	10
1	326	11
1	326	12
1	326	13
1	326	15
1	326	17
1	326	18
1	326	24
1	326	25
1	327	1
1	327	2
1	327	3
1	327	4
1	327	8
1	327	12
1	327	13
1	327	14
1	327	15
1	327	16
1	327	17
1	327	18
1	327	19
1	327	21
1	327	23
1	328	2
1	328	3
1	328	4
1	328	5
1	328	11
1	328	12
1	328	13
1	328	15
1	328	18
1	328	19
1	328	21
1	328	22
1	328	23
1	328	24
1	328	25
1	329	1
1	329	2
1	329	3
1	329	4
1	329	8
1	329	9
1	329	13
1	329	14
1	329	17
1	329	18
1	329	20
1	329	21
1	329	23
1	329	24
1	329	25
1	330	1
1	330	2
1	330	5
1	330	6
1	330	9
1	330	12
1	330	14
1	330	15
1	330	17
1	330	18
1	330	19
1	330	22
1	330	23
1	330	24
1	330	25
1	331	1
1	331	3
1	331	5
1	331	6
1	331	7
1	331	12
1	331	13
1	331	15
1	331	16
1	331	18
1	331	19
1	331	21
1	331	22
1	331	23
1	331	25
1	332	2
1	332	3
1	332	5
1	332	6
1	332	7
1	332	10
1	332	11
1	332	12
1	332	14
1	332	19
1	332	20
1	332	21
1	332	23
1	332	24
1	332	25
1	333	1
1	333	2
1	333	5
1	333	6
1	333	9
1	333	11
1	333	12
1	333	13
1	333	14
1	333	15
1	333	16
1	333	18
1	333	21
1	333	23
1	333	25
1	334	1
1	334	2
1	334	6
1	334	7
1	334	8
1	334	11
1	334	13
1	334	15
1	334	16
1	334	17
1	334	18
1	334	21
1	334	22
1	334	23
1	334	25
1	335	1
1	335	3
1	335	4
1	335	6
1	335	7
1	335	8
1	335	9
1	335	11
1	335	12
1	335	14
1	335	16
1	335	17
1	335	19
1	335	20
1	335	21
1	336	1
1	336	2
1	336	3
1	336	5
1	336	6
1	336	8
1	336	10
1	336	11
1	336	14
1	336	15
1	336	16
1	336	17
1	336	19
1	336	22
1	336	25
1	337	1
1	337	3
1	337	4
1	337	5
1	337	7
1	337	8
1	337	9
1	337	10
1	337	11
1	337	12
1	337	16
1	337	18
1	337	19
1	337	22
1	337	23
1	338	3
1	338	4
1	338	5
1	338	6
1	338	7
1	338	9
1	338	12
1	338	14
1	338	15
1	338	16
1	338	17
1	338	19
1	338	20
1	338	21
1	338	25
1	339	1
1	339	2
1	339	5
1	339	8
1	339	10
1	339	13
1	339	15
1	339	16
1	339	18
1	339	19
1	339	20
1	339	21
1	339	22
1	339	23
1	339	24
1	340	2
1	340	3
1	340	4
1	340	5
1	340	6
1	340	8
1	340	9
1	340	10
1	340	11
1	340	14
1	340	19
1	340	20
1	340	21
1	340	22
1	340	25
1	341	1
1	341	5
1	341	7
1	341	9
1	341	11
1	341	12
1	341	13
1	341	16
1	341	18
1	341	19
1	341	20
1	341	21
1	341	22
1	341	24
1	341	25
1	342	1
1	342	3
1	342	4
1	342	8
1	342	11
1	342	12
1	342	13
1	342	15
1	342	16
1	342	19
1	342	20
1	342	21
1	342	22
1	342	23
1	342	25
1	343	3
1	343	5
1	343	6
1	343	8
1	343	11
1	343	12
1	343	13
1	343	14
1	343	15
1	343	16
1	343	18
1	343	19
1	343	20
1	343	22
1	343	25
1	344	3
1	344	4
1	344	5
1	344	6
1	344	9
1	344	10
1	344	11
1	344	12
1	344	13
1	344	15
1	344	16
1	344	20
1	344	21
1	344	24
1	344	25
1	345	2
1	345	7
1	345	9
1	345	11
1	345	12
1	345	14
1	345	15
1	345	16
1	345	18
1	345	19
1	345	20
1	345	21
1	345	23
1	345	24
1	345	25
1	346	1
1	346	2
1	346	3
1	346	5
1	346	6
1	346	8
1	346	10
1	346	12
1	346	14
1	346	15
1	346	17
1	346	18
1	346	21
1	346	23
1	346	24
1	347	3
1	347	5
1	347	7
1	347	8
1	347	9
1	347	10
1	347	11
1	347	12
1	347	14
1	347	15
1	347	18
1	347	19
1	347	20
1	347	24
1	347	25
1	348	1
1	348	2
1	348	5
1	348	7
1	348	8
1	348	12
1	348	14
1	348	17
1	348	18
1	348	19
1	348	20
1	348	21
1	348	22
1	348	24
1	348	25
1	349	1
1	349	2
1	349	5
1	349	7
1	349	8
1	349	12
1	349	14
1	349	16
1	349	17
1	349	18
1	349	19
1	349	20
1	349	22
1	349	24
1	349	25
1	350	1
1	350	2
1	350	3
1	350	4
1	350	6
1	350	7
1	350	8
1	350	9
1	350	12
1	350	13
1	350	14
1	350	15
1	350	22
1	350	23
1	350	25
1	351	1
1	351	2
1	351	3
1	351	5
1	351	7
1	351	10
1	351	11
1	351	12
1	351	14
1	351	16
1	351	17
1	351	18
1	351	19
1	351	23
1	351	24
1	352	1
1	352	2
1	352	3
1	352	4
1	352	6
1	352	9
1	352	12
1	352	13
1	352	15
1	352	17
1	352	18
1	352	19
1	352	20
1	352	22
1	352	24
1	353	2
1	353	3
1	353	7
1	353	8
1	353	9
1	353	11
1	353	12
1	353	13
1	353	17
1	353	18
1	353	19
1	353	20
1	353	21
1	353	22
1	353	23
1	354	1
1	354	2
1	354	4
1	354	7
1	354	8
1	354	9
1	354	10
1	354	12
1	354	16
1	354	17
1	354	18
1	354	19
1	354	21
1	354	22
1	354	23
1	355	2
1	355	4
1	355	6
1	355	7
1	355	8
1	355	9
1	355	10
1	355	11
1	355	12
1	355	13
1	355	15
1	355	18
1	355	19
1	355	23
1	355	25
1	356	2
1	356	4
1	356	5
1	356	9
1	356	10
1	356	11
1	356	13
1	356	14
1	356	15
1	356	16
1	356	19
1	356	20
1	356	22
1	356	24
1	356	25
1	357	1
1	357	2
1	357	5
1	357	6
1	357	8
1	357	9
1	357	10
1	357	11
1	357	13
1	357	14
1	357	17
1	357	19
1	357	21
1	357	23
1	357	25
1	358	2
1	358	4
1	358	6
1	358	9
1	358	10
1	358	11
1	358	12
1	358	14
1	358	15
1	358	16
1	358	17
1	358	18
1	358	23
1	358	24
1	358	25
1	359	4
1	359	7
1	359	8
1	359	10
1	359	11
1	359	12
1	359	13
1	359	16
1	359	17
1	359	18
1	359	19
1	359	21
1	359	22
1	359	24
1	359	25
1	360	1
1	360	2
1	360	3
1	360	4
1	360	5
1	360	7
1	360	8
1	360	9
1	360	11
1	360	17
1	360	18
1	360	19
1	360	20
1	360	23
1	360	24
1	361	1
1	361	4
1	361	7
1	361	9
1	361	10
1	361	12
1	361	13
1	361	14
1	361	15
1	361	16
1	361	17
1	361	19
1	361	20
1	361	23
1	361	24
1	362	1
1	362	2
1	362	3
1	362	4
1	362	5
1	362	6
1	362	7
1	362	10
1	362	12
1	362	13
1	362	17
1	362	18
1	362	22
1	362	23
1	362	24
1	363	2
1	363	3
1	363	4
1	363	6
1	363	8
1	363	9
1	363	11
1	363	13
1	363	15
1	363	16
1	363	17
1	363	20
1	363	21
1	363	22
1	363	23
1	364	2
1	364	3
1	364	4
1	364	6
1	364	7
1	364	9
1	364	11
1	364	12
1	364	13
1	364	15
1	364	19
1	364	20
1	364	21
1	364	22
1	364	24
1	365	3
1	365	4
1	365	5
1	365	8
1	365	10
1	365	11
1	365	12
1	365	15
1	365	16
1	365	18
1	365	19
1	365	20
1	365	23
1	365	24
1	365	25
1	366	3
1	366	5
1	366	6
1	366	8
1	366	9
1	366	11
1	366	13
1	366	15
1	366	17
1	366	18
1	366	20
1	366	21
1	366	22
1	366	23
1	366	25
1	367	1
1	367	2
1	367	4
1	367	7
1	367	8
1	367	9
1	367	12
1	367	13
1	367	15
1	367	17
1	367	18
1	367	20
1	367	21
1	367	22
1	367	24
1	368	2
1	368	3
1	368	4
1	368	5
1	368	6
1	368	11
1	368	13
1	368	14
1	368	15
1	368	17
1	368	19
1	368	20
1	368	21
1	368	22
1	368	24
1	369	1
1	369	3
1	369	5
1	369	6
1	369	7
1	369	9
1	369	11
1	369	12
1	369	14
1	369	15
1	369	20
1	369	21
1	369	22
1	369	23
1	369	24
1	370	3
1	370	4
1	370	6
1	370	7
1	370	8
1	370	9
1	370	10
1	370	11
1	370	12
1	370	14
1	370	16
1	370	17
1	370	19
1	370	23
1	370	25
1	371	1
1	371	2
1	371	3
1	371	5
1	371	6
1	371	7
1	371	8
1	371	9
1	371	10
1	371	13
1	371	14
1	371	15
1	371	16
1	371	22
1	371	25
1	372	3
1	372	4
1	372	5
1	372	6
1	372	10
1	372	12
1	372	13
1	372	14
1	372	16
1	372	17
1	372	19
1	372	22
1	372	23
1	372	24
1	372	25
1	373	2
1	373	4
1	373	6
1	373	9
1	373	11
1	373	12
1	373	13
1	373	14
1	373	15
1	373	17
1	373	19
1	373	20
1	373	21
1	373	22
1	373	23
1	374	1
1	374	2
1	374	3
1	374	6
1	374	9
1	374	12
1	374	13
1	374	16
1	374	18
1	374	20
1	374	21
1	374	22
1	374	23
1	374	24
1	374	25
1	375	1
1	375	2
1	375	5
1	375	7
1	375	10
1	375	11
1	375	12
1	375	13
1	375	14
1	375	16
1	375	17
1	375	18
1	375	19
1	375	20
1	375	25
1	376	2
1	376	3
1	376	8
1	376	10
1	376	12
1	376	13
1	376	14
1	376	15
1	376	16
1	376	18
1	376	20
1	376	21
1	376	22
1	376	24
1	376	25
1	377	1
1	377	2
1	377	3
1	377	4
1	377	7
1	377	8
1	377	9
1	377	11
1	377	12
1	377	13
1	377	15
1	377	17
1	377	19
1	377	20
1	377	22
1	378	2
1	378	3
1	378	4
1	378	6
1	378	12
1	378	13
1	378	14
1	378	15
1	378	16
1	378	19
1	378	21
1	378	22
1	378	23
1	378	24
1	378	25
1	379	3
1	379	4
1	379	5
1	379	7
1	379	10
1	379	11
1	379	12
1	379	13
1	379	14
1	379	16
1	379	17
1	379	18
1	379	21
1	379	22
1	379	25
1	380	2
1	380	3
1	380	4
1	380	6
1	380	7
1	380	8
1	380	9
1	380	10
1	380	11
1	380	14
1	380	17
1	380	18
1	380	22
1	380	23
1	380	25
1	381	1
1	381	3
1	381	4
1	381	6
1	381	7
1	381	9
1	381	10
1	381	12
1	381	13
1	381	15
1	381	17
1	381	19
1	381	21
1	381	22
1	381	25
1	382	2
1	382	3
1	382	4
1	382	7
1	382	8
1	382	9
1	382	10
1	382	11
1	382	12
1	382	14
1	382	15
1	382	16
1	382	21
1	382	22
1	382	24
1	383	3
1	383	5
1	383	6
1	383	7
1	383	9
1	383	11
1	383	12
1	383	14
1	383	15
1	383	16
1	383	18
1	383	22
1	383	23
1	383	24
1	383	25
1	384	1
1	384	3
1	384	4
1	384	7
1	384	10
1	384	11
1	384	13
1	384	15
1	384	17
1	384	18
1	384	19
1	384	20
1	384	21
1	384	22
1	384	25
1	385	1
1	385	2
1	385	4
1	385	5
1	385	6
1	385	8
1	385	12
1	385	13
1	385	15
1	385	18
1	385	20
1	385	22
1	385	23
1	385	24
1	385	25
1	386	1
1	386	2
1	386	3
1	386	4
1	386	6
1	386	7
1	386	9
1	386	11
1	386	15
1	386	18
1	386	19
1	386	20
1	386	21
1	386	23
1	386	25
1	387	2
1	387	3
1	387	4
1	387	8
1	387	9
1	387	10
1	387	11
1	387	12
1	387	14
1	387	15
1	387	19
1	387	20
1	387	21
1	387	22
1	387	23
1	388	1
1	388	2
1	388	3
1	388	5
1	388	6
1	388	7
1	388	9
1	388	10
1	388	11
1	388	15
1	388	16
1	388	17
1	388	18
1	388	20
1	388	21
1	389	2
1	389	3
1	389	4
1	389	5
1	389	6
1	389	9
1	389	10
1	389	12
1	389	13
1	389	17
1	389	18
1	389	19
1	389	23
1	389	24
1	389	25
1	390	2
1	390	5
1	390	7
1	390	10
1	390	11
1	390	12
1	390	13
1	390	14
1	390	15
1	390	19
1	390	20
1	390	21
1	390	22
1	390	24
1	390	25
1	391	1
1	391	3
1	391	4
1	391	6
1	391	8
1	391	9
1	391	12
1	391	13
1	391	15
1	391	16
1	391	18
1	391	21
1	391	22
1	391	23
1	391	25
1	392	1
1	392	2
1	392	3
1	392	4
1	392	10
1	392	11
1	392	12
1	392	14
1	392	15
1	392	17
1	392	18
1	392	20
1	392	21
1	392	23
1	392	25
1	393	1
1	393	3
1	393	4
1	393	6
1	393	7
1	393	8
1	393	10
1	393	11
1	393	17
1	393	18
1	393	20
1	393	21
1	393	22
1	393	23
1	393	25
1	394	2
1	394	5
1	394	6
1	394	7
1	394	8
1	394	12
1	394	13
1	394	14
1	394	16
1	394	18
1	394	20
1	394	21
1	394	22
1	394	23
1	394	24
1	395	1
1	395	2
1	395	4
1	395	6
1	395	8
1	395	9
1	395	11
1	395	13
1	395	14
1	395	15
1	395	17
1	395	21
1	395	22
1	395	23
1	395	25
1	396	1
1	396	2
1	396	3
1	396	5
1	396	6
1	396	7
1	396	9
1	396	10
1	396	11
1	396	13
1	396	15
1	396	18
1	396	20
1	396	22
1	396	24
1	397	1
1	397	2
1	397	3
1	397	4
1	397	5
1	397	6
1	397	8
1	397	9
1	397	10
1	397	13
1	397	14
1	397	15
1	397	20
1	397	22
1	397	25
1	398	2
1	398	3
1	398	4
1	398	5
1	398	7
1	398	8
1	398	9
1	398	10
1	398	12
1	398	13
1	398	16
1	398	18
1	398	20
1	398	21
1	398	22
1	399	1
1	399	4
1	399	7
1	399	9
1	399	10
1	399	11
1	399	12
1	399	14
1	399	16
1	399	17
1	399	19
1	399	21
1	399	22
1	399	23
1	399	24
1	400	1
1	400	5
1	400	9
1	400	10
1	400	12
1	400	14
1	400	15
1	400	16
1	400	17
1	400	19
1	400	20
1	400	21
1	400	22
1	400	23
1	400	24
1	401	1
1	401	2
1	401	3
1	401	5
1	401	6
1	401	7
1	401	8
1	401	10
1	401	14
1	401	16
1	401	17
1	401	21
1	401	23
1	401	24
1	401	25
1	402	1
1	402	2
1	402	4
1	402	6
1	402	7
1	402	8
1	402	9
1	402	11
1	402	16
1	402	20
1	402	21
1	402	22
1	402	23
1	402	24
1	402	25
1	403	2
1	403	4
1	403	6
1	403	7
1	403	8
1	403	9
1	403	11
1	403	12
1	403	13
1	403	14
1	403	15
1	403	19
1	403	21
1	403	24
1	403	25
1	404	1
1	404	5
1	404	6
1	404	8
1	404	10
1	404	11
1	404	13
1	404	14
1	404	16
1	404	18
1	404	20
1	404	21
1	404	22
1	404	24
1	404	25
1	405	4
1	405	5
1	405	6
1	405	7
1	405	8
1	405	11
1	405	12
1	405	13
1	405	14
1	405	16
1	405	18
1	405	19
1	405	22
1	405	24
1	405	25
1	406	1
1	406	2
1	406	4
1	406	5
1	406	7
1	406	8
1	406	9
1	406	10
1	406	11
1	406	16
1	406	17
1	406	21
1	406	22
1	406	23
1	406	24
1	407	2
1	407	4
1	407	6
1	407	7
1	407	8
1	407	9
1	407	11
1	407	12
1	407	14
1	407	15
1	407	16
1	407	17
1	407	20
1	407	22
1	407	25
1	408	1
1	408	2
1	408	3
1	408	4
1	408	10
1	408	11
1	408	12
1	408	14
1	408	15
1	408	18
1	408	19
1	408	20
1	408	21
1	408	22
1	408	23
1	409	1
1	409	2
1	409	4
1	409	6
1	409	7
1	409	8
1	409	10
1	409	14
1	409	16
1	409	17
1	409	20
1	409	21
1	409	23
1	409	24
1	409	25
1	410	1
1	410	4
1	410	5
1	410	7
1	410	8
1	410	9
1	410	10
1	410	11
1	410	13
1	410	14
1	410	15
1	410	17
1	410	18
1	410	19
1	410	25
1	411	1
1	411	5
1	411	7
1	411	9
1	411	11
1	411	12
1	411	14
1	411	16
1	411	17
1	411	18
1	411	20
1	411	21
1	411	22
1	411	24
1	411	25
1	412	3
1	412	4
1	412	8
1	412	9
1	412	10
1	412	11
1	412	12
1	412	16
1	412	17
1	412	18
1	412	19
1	412	20
1	412	21
1	412	22
1	412	25
1	413	2
1	413	3
1	413	5
1	413	6
1	413	8
1	413	9
1	413	10
1	413	12
1	413	13
1	413	14
1	413	16
1	413	17
1	413	20
1	413	21
1	413	25
1	414	2
1	414	3
1	414	5
1	414	6
1	414	8
1	414	9
1	414	10
1	414	11
1	414	15
1	414	16
1	414	18
1	414	19
1	414	20
1	414	21
1	414	25
1	415	1
1	415	3
1	415	7
1	415	10
1	415	11
1	415	13
1	415	14
1	415	15
1	415	17
1	415	18
1	415	19
1	415	20
1	415	21
1	415	22
1	415	23
1	416	1
1	416	2
1	416	5
1	416	6
1	416	7
1	416	13
1	416	15
1	416	16
1	416	18
1	416	19
1	416	20
1	416	22
1	416	23
1	416	24
1	416	25
1	417	1
1	417	2
1	417	3
1	417	8
1	417	9
1	417	11
1	417	12
1	417	13
1	417	14
1	417	15
1	417	16
1	417	17
1	417	19
1	417	21
1	417	23
1	418	5
1	418	8
1	418	9
1	418	10
1	418	11
1	418	12
1	418	13
1	418	14
1	418	18
1	418	19
1	418	20
1	418	22
1	418	23
1	418	24
1	418	25
1	419	3
1	419	4
1	419	5
1	419	6
1	419	7
1	419	14
1	419	15
1	419	16
1	419	17
1	419	18
1	419	20
1	419	21
1	419	22
1	419	23
1	419	24
1	420	3
1	420	4
1	420	5
1	420	6
1	420	7
1	420	8
1	420	9
1	420	10
1	420	11
1	420	12
1	420	18
1	420	19
1	420	22
1	420	24
1	420	25
1	421	3
1	421	4
1	421	5
1	421	8
1	421	9
1	421	10
1	421	12
1	421	13
1	421	14
1	421	15
1	421	16
1	421	19
1	421	20
1	421	23
1	421	25
1	422	1
1	422	2
1	422	3
1	422	4
1	422	6
1	422	7
1	422	8
1	422	12
1	422	13
1	422	14
1	422	17
1	422	18
1	422	22
1	422	23
1	422	25
1	423	1
1	423	2
1	423	3
1	423	5
1	423	11
1	423	13
1	423	15
1	423	16
1	423	17
1	423	18
1	423	20
1	423	22
1	423	23
1	423	24
1	423	25
1	424	1
1	424	3
1	424	6
1	424	9
1	424	10
1	424	11
1	424	13
1	424	14
1	424	15
1	424	16
1	424	17
1	424	18
1	424	19
1	424	24
1	424	25
1	425	1
1	425	7
1	425	9
1	425	10
1	425	11
1	425	12
1	425	13
1	425	15
1	425	16
1	425	18
1	425	19
1	425	20
1	425	22
1	425	23
1	425	24
1	426	2
1	426	3
1	426	4
1	426	5
1	426	6
1	426	8
1	426	10
1	426	11
1	426	15
1	426	16
1	426	18
1	426	19
1	426	22
1	426	24
1	426	25
1	427	1
1	427	3
1	427	4
1	427	5
1	427	6
1	427	7
1	427	9
1	427	10
1	427	11
1	427	12
1	427	16
1	427	19
1	427	21
1	427	22
1	427	24
1	428	1
1	428	3
1	428	4
1	428	11
1	428	13
1	428	14
1	428	15
1	428	17
1	428	18
1	428	19
1	428	20
1	428	21
1	428	22
1	428	23
1	428	24
1	429	2
1	429	3
1	429	4
1	429	5
1	429	6
1	429	7
1	429	8
1	429	12
1	429	13
1	429	14
1	429	16
1	429	17
1	429	19
1	429	23
1	429	25
1	430	2
1	430	3
1	430	4
1	430	5
1	430	6
1	430	7
1	430	9
1	430	11
1	430	13
1	430	14
1	430	15
1	430	20
1	430	22
1	430	23
1	430	25
1	431	1
1	431	2
1	431	3
1	431	5
1	431	9
1	431	11
1	431	12
1	431	13
1	431	15
1	431	18
1	431	20
1	431	21
1	431	22
1	431	23
1	431	24
1	432	2
1	432	3
1	432	4
1	432	6
1	432	7
1	432	10
1	432	12
1	432	13
1	432	15
1	432	17
1	432	19
1	432	20
1	432	21
1	432	23
1	432	24
1	433	1
1	433	2
1	433	3
1	433	5
1	433	7
1	433	8
1	433	9
1	433	14
1	433	15
1	433	19
1	433	21
1	433	22
1	433	23
1	433	24
1	433	25
1	434	3
1	434	4
1	434	6
1	434	9
1	434	11
1	434	12
1	434	13
1	434	15
1	434	16
1	434	17
1	434	18
1	434	21
1	434	23
1	434	24
1	434	25
1	435	1
1	435	3
1	435	4
1	435	5
1	435	10
1	435	11
1	435	13
1	435	14
1	435	15
1	435	16
1	435	17
1	435	18
1	435	21
1	435	24
1	435	25
1	436	3
1	436	4
1	436	6
1	436	7
1	436	10
1	436	13
1	436	14
1	436	15
1	436	18
1	436	19
1	436	20
1	436	21
1	436	22
1	436	23
1	436	25
1	437	1
1	437	2
1	437	4
1	437	5
1	437	6
1	437	8
1	437	10
1	437	11
1	437	12
1	437	16
1	437	17
1	437	19
1	437	20
1	437	21
1	437	23
1	438	1
1	438	4
1	438	7
1	438	8
1	438	9
1	438	11
1	438	13
1	438	15
1	438	17
1	438	18
1	438	21
1	438	22
1	438	23
1	438	24
1	438	25
1	439	2
1	439	3
1	439	5
1	439	9
1	439	10
1	439	11
1	439	12
1	439	14
1	439	15
1	439	17
1	439	19
1	439	21
1	439	23
1	439	24
1	439	25
1	440	1
1	440	3
1	440	5
1	440	8
1	440	9
1	440	12
1	440	13
1	440	14
1	440	15
1	440	16
1	440	19
1	440	21
1	440	22
1	440	24
1	440	25
1	441	1
1	441	2
1	441	3
1	441	4
1	441	7
1	441	8
1	441	9
1	441	10
1	441	11
1	441	13
1	441	14
1	441	20
1	441	23
1	441	24
1	441	25
1	442	5
1	442	6
1	442	7
1	442	8
1	442	9
1	442	12
1	442	13
1	442	14
1	442	15
1	442	17
1	442	18
1	442	22
1	442	23
1	442	24
1	442	25
1	443	1
1	443	2
1	443	3
1	443	5
1	443	7
1	443	10
1	443	11
1	443	12
1	443	16
1	443	17
1	443	18
1	443	19
1	443	21
1	443	22
1	443	23
1	444	1
1	444	2
1	444	3
1	444	6
1	444	7
1	444	10
1	444	14
1	444	15
1	444	18
1	444	19
1	444	20
1	444	21
1	444	22
1	444	24
1	444	25
1	445	1
1	445	2
1	445	4
1	445	7
1	445	9
1	445	10
1	445	11
1	445	12
1	445	13
1	445	15
1	445	16
1	445	18
1	445	19
1	445	20
1	445	21
1	446	1
1	446	2
1	446	4
1	446	5
1	446	6
1	446	8
1	446	10
1	446	11
1	446	14
1	446	15
1	446	16
1	446	19
1	446	21
1	446	23
1	446	24
1	447	1
1	447	2
1	447	5
1	447	8
1	447	10
1	447	12
1	447	16
1	447	17
1	447	18
1	447	19
1	447	20
1	447	21
1	447	22
1	447	24
1	447	25
1	448	1
1	448	3
1	448	5
1	448	6
1	448	9
1	448	10
1	448	11
1	448	12
1	448	13
1	448	14
1	448	15
1	448	17
1	448	20
1	448	23
1	448	24
1	449	1
1	449	2
1	449	3
1	449	4
1	449	8
1	449	9
1	449	10
1	449	11
1	449	16
1	449	17
1	449	18
1	449	19
1	449	22
1	449	24
1	449	25
1	450	4
1	450	5
1	450	6
1	450	7
1	450	9
1	450	11
1	450	14
1	450	16
1	450	17
1	450	18
1	450	21
1	450	22
1	450	23
1	450	24
1	450	25
1	451	1
1	451	3
1	451	5
1	451	6
1	451	8
1	451	9
1	451	14
1	451	15
1	451	17
1	451	18
1	451	19
1	451	22
1	451	23
1	451	24
1	451	25
1	452	1
1	452	6
1	452	7
1	452	8
1	452	9
1	452	10
1	452	11
1	452	12
1	452	14
1	452	17
1	452	18
1	452	19
1	452	20
1	452	24
1	452	25
1	453	1
1	453	2
1	453	3
1	453	4
1	453	6
1	453	9
1	453	11
1	453	14
1	453	15
1	453	17
1	453	19
1	453	20
1	453	21
1	453	24
1	453	25
1	454	3
1	454	4
1	454	6
1	454	7
1	454	11
1	454	12
1	454	13
1	454	14
1	454	15
1	454	17
1	454	19
1	454	20
1	454	22
1	454	24
1	454	25
1	455	1
1	455	3
1	455	4
1	455	5
1	455	6
1	455	7
1	455	8
1	455	11
1	455	12
1	455	14
1	455	18
1	455	19
1	455	21
1	455	23
1	455	25
1	456	1
1	456	3
1	456	4
1	456	9
1	456	10
1	456	11
1	456	12
1	456	13
1	456	14
1	456	17
1	456	18
1	456	21
1	456	23
1	456	24
1	456	25
1	457	1
1	457	4
1	457	5
1	457	11
1	457	13
1	457	14
1	457	15
1	457	16
1	457	18
1	457	19
1	457	20
1	457	21
1	457	22
1	457	23
1	457	25
1	458	2
1	458	3
1	458	4
1	458	5
1	458	6
1	458	7
1	458	8
1	458	9
1	458	11
1	458	13
1	458	15
1	458	16
1	458	18
1	458	20
1	458	22
1	459	1
1	459	2
1	459	3
1	459	4
1	459	7
1	459	10
1	459	11
1	459	12
1	459	14
1	459	15
1	459	17
1	459	19
1	459	20
1	459	21
1	459	23
1	460	1
1	460	3
1	460	4
1	460	6
1	460	9
1	460	10
1	460	11
1	460	12
1	460	14
1	460	15
1	460	16
1	460	17
1	460	19
1	460	22
1	460	23
1	461	3
1	461	4
1	461	5
1	461	6
1	461	7
1	461	8
1	461	11
1	461	12
1	461	13
1	461	14
1	461	15
1	461	17
1	461	19
1	461	23
1	461	24
1	462	1
1	462	2
1	462	3
1	462	5
1	462	7
1	462	8
1	462	12
1	462	14
1	462	16
1	462	17
1	462	18
1	462	21
1	462	22
1	462	23
1	462	24
1	463	2
1	463	3
1	463	6
1	463	7
1	463	9
1	463	11
1	463	13
1	463	14
1	463	17
1	463	18
1	463	19
1	463	20
1	463	22
1	463	23
1	463	25
1	464	1
1	464	2
1	464	5
1	464	8
1	464	10
1	464	11
1	464	16
1	464	17
1	464	19
1	464	20
1	464	21
1	464	22
1	464	23
1	464	24
1	464	25
1	465	1
1	465	2
1	465	3
1	465	4
1	465	6
1	465	7
1	465	9
1	465	10
1	465	11
1	465	13
1	465	18
1	465	19
1	465	21
1	465	22
1	465	25
1	466	2
1	466	6
1	466	7
1	466	8
1	466	10
1	466	11
1	466	12
1	466	14
1	466	17
1	466	18
1	466	19
1	466	20
1	466	21
1	466	22
1	466	25
1	467	2
1	467	4
1	467	5
1	467	6
1	467	7
1	467	10
1	467	13
1	467	14
1	467	15
1	467	17
1	467	18
1	467	21
1	467	22
1	467	24
1	467	25
1	468	2
1	468	3
1	468	5
1	468	6
1	468	9
1	468	10
1	468	12
1	468	13
1	468	15
1	468	17
1	468	18
1	468	21
1	468	22
1	468	24
1	468	25
1	469	1
1	469	2
1	469	5
1	469	6
1	469	7
1	469	8
1	469	10
1	469	11
1	469	13
1	469	14
1	469	18
1	469	19
1	469	22
1	469	23
1	469	25
1	470	1
1	470	3
1	470	4
1	470	5
1	470	6
1	470	7
1	470	8
1	470	10
1	470	11
1	470	13
1	470	15
1	470	18
1	470	20
1	470	22
1	470	23
1	471	2
1	471	3
1	471	4
1	471	6
1	471	9
1	471	10
1	471	11
1	471	12
1	471	13
1	471	14
1	471	15
1	471	16
1	471	20
1	471	24
1	471	25
1	472	1
1	472	2
1	472	4
1	472	5
1	472	6
1	472	7
1	472	8
1	472	11
1	472	12
1	472	13
1	472	14
1	472	15
1	472	17
1	472	18
1	472	20
1	473	1
1	473	2
1	473	5
1	473	6
1	473	7
1	473	8
1	473	9
1	473	11
1	473	12
1	473	15
1	473	17
1	473	19
1	473	22
1	473	23
1	473	25
1	474	1
1	474	2
1	474	3
1	474	5
1	474	9
1	474	10
1	474	11
1	474	12
1	474	15
1	474	16
1	474	17
1	474	18
1	474	21
1	474	23
1	474	24
1	475	2
1	475	3
1	475	4
1	475	5
1	475	6
1	475	9
1	475	10
1	475	11
1	475	13
1	475	14
1	475	17
1	475	20
1	475	21
1	475	23
1	475	25
1	476	1
1	476	5
1	476	6
1	476	7
1	476	9
1	476	10
1	476	11
1	476	13
1	476	14
1	476	15
1	476	16
1	476	17
1	476	19
1	476	24
1	476	25
1	477	2
1	477	4
1	477	6
1	477	7
1	477	8
1	477	10
1	477	11
1	477	12
1	477	14
1	477	16
1	477	18
1	477	20
1	477	23
1	477	24
1	477	25
1	478	2
1	478	3
1	478	5
1	478	7
1	478	9
1	478	10
1	478	11
1	478	12
1	478	13
1	478	16
1	478	18
1	478	22
1	478	23
1	478	24
1	478	25
1	479	2
1	479	3
1	479	5
1	479	8
1	479	11
1	479	13
1	479	14
1	479	15
1	479	16
1	479	18
1	479	19
1	479	22
1	479	23
1	479	24
1	479	25
1	480	4
1	480	5
1	480	6
1	480	7
1	480	8
1	480	9
1	480	11
1	480	12
1	480	15
1	480	17
1	480	18
1	480	19
1	480	22
1	480	24
1	480	25
1	481	1
1	481	3
1	481	5
1	481	7
1	481	9
1	481	10
1	481	12
1	481	13
1	481	14
1	481	15
1	481	17
1	481	20
1	481	21
1	481	22
1	481	24
1	482	2
1	482	6
1	482	7
1	482	8
1	482	9
1	482	10
1	482	12
1	482	15
1	482	16
1	482	17
1	482	19
1	482	21
1	482	22
1	482	23
1	482	25
1	483	1
1	483	4
1	483	5
1	483	6
1	483	7
1	483	9
1	483	11
1	483	12
1	483	14
1	483	17
1	483	18
1	483	21
1	483	22
1	483	23
1	483	24
1	484	1
1	484	4
1	484	6
1	484	8
1	484	9
1	484	10
1	484	11
1	484	13
1	484	14
1	484	16
1	484	17
1	484	20
1	484	21
1	484	23
1	484	25
1	485	2
1	485	3
1	485	4
1	485	5
1	485	6
1	485	7
1	485	11
1	485	16
1	485	17
1	485	18
1	485	20
1	485	21
1	485	22
1	485	24
1	485	25
1	486	1
1	486	2
1	486	3
1	486	4
1	486	5
1	486	7
1	486	9
1	486	11
1	486	13
1	486	15
1	486	18
1	486	19
1	486	20
1	486	21
1	486	22
1	487	4
1	487	5
1	487	6
1	487	7
1	487	8
1	487	9
1	487	10
1	487	14
1	487	15
1	487	17
1	487	18
1	487	19
1	487	21
1	487	22
1	487	24
1	488	5
1	488	6
1	488	7
1	488	8
1	488	11
1	488	12
1	488	13
1	488	14
1	488	15
1	488	17
1	488	18
1	488	20
1	488	22
1	488	24
1	488	25
1	489	1
1	489	2
1	489	5
1	489	7
1	489	10
1	489	11
1	489	12
1	489	14
1	489	17
1	489	18
1	489	19
1	489	21
1	489	22
1	489	23
1	489	25
1	490	3
1	490	5
1	490	6
1	490	8
1	490	10
1	490	11
1	490	12
1	490	13
1	490	14
1	490	16
1	490	17
1	490	18
1	490	21
1	490	22
1	490	23
1	491	1
1	491	2
1	491	3
1	491	7
1	491	9
1	491	11
1	491	12
1	491	13
1	491	16
1	491	20
1	491	21
1	491	22
1	491	23
1	491	24
1	491	25
1	492	1
1	492	2
1	492	3
1	492	4
1	492	6
1	492	8
1	492	11
1	492	12
1	492	14
1	492	15
1	492	18
1	492	19
1	492	21
1	492	24
1	492	25
1	493	1
1	493	4
1	493	5
1	493	7
1	493	8
1	493	10
1	493	12
1	493	13
1	493	14
1	493	15
1	493	17
1	493	18
1	493	21
1	493	22
1	493	25
1	494	2
1	494	3
1	494	4
1	494	5
1	494	7
1	494	8
1	494	12
1	494	13
1	494	15
1	494	16
1	494	18
1	494	19
1	494	20
1	494	21
1	494	22
1	495	1
1	495	3
1	495	4
1	495	6
1	495	7
1	495	8
1	495	9
1	495	11
1	495	13
1	495	15
1	495	17
1	495	19
1	495	22
1	495	24
1	495	25
1	496	3
1	496	4
1	496	5
1	496	7
1	496	9
1	496	11
1	496	13
1	496	14
1	496	15
1	496	16
1	496	17
1	496	19
1	496	21
1	496	22
1	496	24
1	497	1
1	497	2
1	497	3
1	497	4
1	497	5
1	497	8
1	497	9
1	497	11
1	497	12
1	497	14
1	497	16
1	497	17
1	497	19
1	497	23
1	497	25
1	498	1
1	498	2
1	498	4
1	498	5
1	498	6
1	498	11
1	498	13
1	498	14
1	498	15
1	498	16
1	498	18
1	498	20
1	498	22
1	498	23
1	498	25
1	499	1
1	499	2
1	499	3
1	499	4
1	499	7
1	499	10
1	499	11
1	499	12
1	499	15
1	499	17
1	499	19
1	499	20
1	499	21
1	499	24
1	499	25
1	500	2
1	500	3
1	500	5
1	500	6
1	500	8
1	500	9
1	500	10
1	500	13
1	500	14
1	500	16
1	500	18
1	500	20
1	500	21
1	500	23
1	500	25
1	501	1
1	501	2
1	501	3
1	501	4
1	501	6
1	501	9
1	501	12
1	501	15
1	501	17
1	501	18
1	501	19
1	501	21
1	501	23
1	501	24
1	501	25
1	502	1
1	502	2
1	502	3
1	502	4
1	502	5
1	502	6
1	502	8
1	502	10
1	502	11
1	502	13
1	502	16
1	502	18
1	502	19
1	502	23
1	502	24
1	503	1
1	503	2
1	503	3
1	503	4
1	503	5
1	503	7
1	503	11
1	503	12
1	503	14
1	503	15
1	503	17
1	503	20
1	503	21
1	503	24
1	503	25
1	504	1
1	504	6
1	504	9
1	504	10
1	504	12
1	504	13
1	504	14
1	504	15
1	504	16
1	504	17
1	504	18
1	504	19
1	504	20
1	504	21
1	504	23
1	505	3
1	505	4
1	505	6
1	505	7
1	505	9
1	505	11
1	505	15
1	505	16
1	505	17
1	505	18
1	505	19
1	505	20
1	505	21
1	505	22
1	505	24
1	506	4
1	506	5
1	506	6
1	506	9
1	506	11
1	506	12
1	506	13
1	506	15
1	506	16
1	506	17
1	506	19
1	506	20
1	506	21
1	506	22
1	506	24
1	507	1
1	507	2
1	507	3
1	507	5
1	507	6
1	507	8
1	507	9
1	507	10
1	507	11
1	507	12
1	507	20
1	507	21
1	507	23
1	507	24
1	507	25
1	508	2
1	508	3
1	508	5
1	508	6
1	508	7
1	508	8
1	508	9
1	508	14
1	508	15
1	508	16
1	508	18
1	508	19
1	508	23
1	508	24
1	508	25
1	509	1
1	509	3
1	509	5
1	509	6
1	509	9
1	509	11
1	509	12
1	509	15
1	509	16
1	509	17
1	509	19
1	509	20
1	509	22
1	509	24
1	509	25
1	510	1
1	510	2
1	510	3
1	510	4
1	510	6
1	510	7
1	510	10
1	510	11
1	510	12
1	510	13
1	510	20
1	510	21
1	510	22
1	510	23
1	510	25
1	511	1
1	511	2
1	511	5
1	511	7
1	511	10
1	511	11
1	511	12
1	511	13
1	511	14
1	511	17
1	511	18
1	511	19
1	511	21
1	511	24
1	511	25
1	512	1
1	512	2
1	512	4
1	512	5
1	512	6
1	512	7
1	512	8
1	512	9
1	512	10
1	512	12
1	512	13
1	512	15
1	512	16
1	512	21
1	512	24
1	513	1
1	513	2
1	513	3
1	513	6
1	513	9
1	513	10
1	513	11
1	513	13
1	513	15
1	513	17
1	513	18
1	513	20
1	513	22
1	513	23
1	513	25
1	514	1
1	514	5
1	514	6
1	514	7
1	514	8
1	514	9
1	514	11
1	514	12
1	514	15
1	514	17
1	514	18
1	514	21
1	514	22
1	514	24
1	514	25
1	515	2
1	515	3
1	515	5
1	515	7
1	515	9
1	515	10
1	515	11
1	515	12
1	515	13
1	515	14
1	515	17
1	515	18
1	515	20
1	515	24
1	515	25
1	516	2
1	516	4
1	516	5
1	516	6
1	516	7
1	516	8
1	516	11
1	516	12
1	516	13
1	516	14
1	516	18
1	516	20
1	516	21
1	516	23
1	516	24
1	517	1
1	517	3
1	517	4
1	517	5
1	517	6
1	517	7
1	517	8
1	517	9
1	517	11
1	517	12
1	517	13
1	517	17
1	517	21
1	517	22
1	517	23
1	518	4
1	518	5
1	518	6
1	518	7
1	518	10
1	518	11
1	518	12
1	518	13
1	518	14
1	518	16
1	518	17
1	518	19
1	518	20
1	518	22
1	518	24
1	519	2
1	519	3
1	519	7
1	519	9
1	519	11
1	519	12
1	519	13
1	519	15
1	519	16
1	519	17
1	519	19
1	519	21
1	519	23
1	519	24
1	519	25
1	520	2
1	520	4
1	520	5
1	520	6
1	520	9
1	520	10
1	520	12
1	520	14
1	520	15
1	520	18
1	520	19
1	520	20
1	520	22
1	520	23
1	520	24
1	521	1
1	521	2
1	521	3
1	521	4
1	521	5
1	521	6
1	521	9
1	521	10
1	521	11
1	521	12
1	521	13
1	521	17
1	521	19
1	521	20
1	521	23
1	522	2
1	522	4
1	522	6
1	522	7
1	522	9
1	522	11
1	522	16
1	522	17
1	522	18
1	522	19
1	522	21
1	522	22
1	522	23
1	522	24
1	522	25
1	523	2
1	523	4
1	523	5
1	523	8
1	523	9
1	523	10
1	523	11
1	523	12
1	523	13
1	523	16
1	523	17
1	523	18
1	523	19
1	523	24
1	523	25
1	524	2
1	524	3
1	524	5
1	524	6
1	524	7
1	524	10
1	524	11
1	524	12
1	524	14
1	524	17
1	524	20
1	524	21
1	524	22
1	524	23
1	524	24
1	525	3
1	525	4
1	525	6
1	525	9
1	525	10
1	525	11
1	525	13
1	525	15
1	525	16
1	525	17
1	525	18
1	525	20
1	525	21
1	525	22
1	525	25
1	526	1
1	526	2
1	526	4
1	526	7
1	526	8
1	526	9
1	526	10
1	526	11
1	526	12
1	526	14
1	526	15
1	526	16
1	526	19
1	526	24
1	526	25
1	527	1
1	527	2
1	527	5
1	527	6
1	527	9
1	527	11
1	527	12
1	527	14
1	527	15
1	527	16
1	527	17
1	527	19
1	527	22
1	527	23
1	527	24
1	528	2
1	528	3
1	528	4
1	528	6
1	528	7
1	528	8
1	528	10
1	528	11
1	528	12
1	528	15
1	528	19
1	528	21
1	528	23
1	528	24
1	528	25
1	529	2
1	529	3
1	529	5
1	529	6
1	529	7
1	529	11
1	529	12
1	529	16
1	529	17
1	529	18
1	529	19
1	529	20
1	529	22
1	529	23
1	529	25
1	530	3
1	530	4
1	530	6
1	530	7
1	530	8
1	530	9
1	530	10
1	530	11
1	530	12
1	530	14
1	530	16
1	530	18
1	530	21
1	530	22
1	530	23
1	531	1
1	531	2
1	531	3
1	531	7
1	531	10
1	531	12
1	531	13
1	531	14
1	531	15
1	531	16
1	531	17
1	531	21
1	531	22
1	531	23
1	531	25
1	532	1
1	532	2
1	532	4
1	532	5
1	532	6
1	532	7
1	532	9
1	532	11
1	532	12
1	532	13
1	532	15
1	532	16
1	532	19
1	532	22
1	532	24
1	533	1
1	533	2
1	533	3
1	533	8
1	533	9
1	533	10
1	533	11
1	533	13
1	533	14
1	533	16
1	533	17
1	533	18
1	533	20
1	533	24
1	533	25
1	534	1
1	534	2
1	534	3
1	534	5
1	534	7
1	534	8
1	534	11
1	534	12
1	534	13
1	534	15
1	534	18
1	534	19
1	534	21
1	534	22
1	534	24
1	535	1
1	535	4
1	535	5
1	535	6
1	535	9
1	535	11
1	535	13
1	535	15
1	535	16
1	535	17
1	535	19
1	535	21
1	535	23
1	535	24
1	535	25
1	536	3
1	536	4
1	536	5
1	536	7
1	536	9
1	536	11
1	536	15
1	536	16
1	536	17
1	536	19
1	536	20
1	536	22
1	536	23
1	536	24
1	536	25
1	537	1
1	537	2
1	537	4
1	537	6
1	537	9
1	537	10
1	537	11
1	537	14
1	537	15
1	537	17
1	537	18
1	537	20
1	537	22
1	537	23
1	537	24
1	538	2
1	538	5
1	538	6
1	538	10
1	538	11
1	538	12
1	538	13
1	538	16
1	538	17
1	538	18
1	538	19
1	538	20
1	538	21
1	538	24
1	538	25
1	539	1
1	539	2
1	539	4
1	539	5
1	539	6
1	539	8
1	539	9
1	539	12
1	539	13
1	539	14
1	539	15
1	539	16
1	539	19
1	539	21
1	539	23
1	540	2
1	540	6
1	540	7
1	540	8
1	540	9
1	540	11
1	540	12
1	540	13
1	540	15
1	540	16
1	540	18
1	540	19
1	540	20
1	540	22
1	540	24
1	541	3
1	541	4
1	541	5
1	541	6
1	541	9
1	541	10
1	541	13
1	541	14
1	541	15
1	541	17
1	541	19
1	541	20
1	541	22
1	541	24
1	541	25
1	542	1
1	542	2
1	542	3
1	542	4
1	542	5
1	542	8
1	542	9
1	542	10
1	542	13
1	542	16
1	542	17
1	542	18
1	542	20
1	542	22
1	542	24
1	543	1
1	543	5
1	543	7
1	543	8
1	543	10
1	543	11
1	543	13
1	543	14
1	543	15
1	543	16
1	543	17
1	543	20
1	543	22
1	543	24
1	543	25
1	544	2
1	544	4
1	544	5
1	544	7
1	544	8
1	544	9
1	544	11
1	544	13
1	544	14
1	544	15
1	544	18
1	544	19
1	544	21
1	544	23
1	544	24
1	545	1
1	545	3
1	545	5
1	545	6
1	545	7
1	545	11
1	545	12
1	545	13
1	545	14
1	545	15
1	545	17
1	545	18
1	545	23
1	545	24
1	545	25
1	546	2
1	546	3
1	546	4
1	546	5
1	546	8
1	546	9
1	546	10
1	546	11
1	546	12
1	546	13
1	546	17
1	546	18
1	546	19
1	546	21
1	546	23
1	547	1
1	547	2
1	547	4
1	547	5
1	547	6
1	547	9
1	547	10
1	547	12
1	547	14
1	547	16
1	547	17
1	547	19
1	547	20
1	547	24
1	547	25
1	548	1
1	548	2
1	548	3
1	548	4
1	548	5
1	548	6
1	548	7
1	548	8
1	548	9
1	548	13
1	548	14
1	548	17
1	548	20
1	548	23
1	548	25
1	549	3
1	549	4
1	549	7
1	549	9
1	549	10
1	549	11
1	549	13
1	549	14
1	549	15
1	549	16
1	549	17
1	549	20
1	549	21
1	549	22
1	549	23
1	550	1
1	550	5
1	550	6
1	550	7
1	550	9
1	550	10
1	550	11
1	550	13
1	550	14
1	550	16
1	550	17
1	550	18
1	550	20
1	550	21
1	550	22
1	551	3
1	551	7
1	551	8
1	551	10
1	551	12
1	551	13
1	551	14
1	551	16
1	551	17
1	551	18
1	551	19
1	551	20
1	551	21
1	551	22
1	551	24
1	552	1
1	552	3
1	552	4
1	552	5
1	552	6
1	552	8
1	552	10
1	552	12
1	552	13
1	552	17
1	552	20
1	552	22
1	552	23
1	552	24
1	552	25
1	553	4
1	553	5
1	553	7
1	553	8
1	553	9
1	553	10
1	553	12
1	553	13
1	553	14
1	553	15
1	553	17
1	553	18
1	553	21
1	553	23
1	553	24
1	554	1
1	554	2
1	554	3
1	554	4
1	554	6
1	554	9
1	554	13
1	554	14
1	554	17
1	554	19
1	554	20
1	554	21
1	554	22
1	554	24
1	554	25
1	555	1
1	555	2
1	555	6
1	555	7
1	555	8
1	555	9
1	555	10
1	555	12
1	555	14
1	555	16
1	555	17
1	555	18
1	555	20
1	555	23
1	555	24
1	556	1
1	556	4
1	556	8
1	556	9
1	556	11
1	556	13
1	556	14
1	556	16
1	556	17
1	556	18
1	556	20
1	556	22
1	556	23
1	556	24
1	556	25
1	557	1
1	557	5
1	557	7
1	557	8
1	557	9
1	557	10
1	557	12
1	557	14
1	557	15
1	557	17
1	557	18
1	557	19
1	557	20
1	557	21
1	557	23
1	558	1
1	558	3
1	558	4
1	558	5
1	558	7
1	558	10
1	558	12
1	558	14
1	558	17
1	558	18
1	558	20
1	558	21
1	558	22
1	558	24
1	558	25
1	559	1
1	559	2
1	559	5
1	559	7
1	559	9
1	559	10
1	559	11
1	559	13
1	559	14
1	559	16
1	559	19
1	559	20
1	559	21
1	559	22
1	559	23
1	560	1
1	560	2
1	560	4
1	560	9
1	560	10
1	560	12
1	560	14
1	560	17
1	560	18
1	560	19
1	560	20
1	560	21
1	560	23
1	560	24
1	560	25
1	561	2
1	561	3
1	561	4
1	561	6
1	561	7
1	561	9
1	561	10
1	561	11
1	561	12
1	561	13
1	561	15
1	561	17
1	561	18
1	561	20
1	561	21
1	562	1
1	562	2
1	562	3
1	562	5
1	562	7
1	562	8
1	562	13
1	562	14
1	562	16
1	562	18
1	562	19
1	562	20
1	562	21
1	562	22
1	562	24
1	563	1
1	563	3
1	563	4
1	563	5
1	563	6
1	563	7
1	563	9
1	563	11
1	563	12
1	563	16
1	563	19
1	563	20
1	563	22
1	563	23
1	563	24
1	564	1
1	564	2
1	564	3
1	564	4
1	564	7
1	564	9
1	564	12
1	564	14
1	564	15
1	564	17
1	564	19
1	564	20
1	564	21
1	564	23
1	564	24
1	565	1
1	565	4
1	565	6
1	565	7
1	565	9
1	565	10
1	565	12
1	565	15
1	565	17
1	565	18
1	565	19
1	565	20
1	565	21
1	565	23
1	565	24
1	566	1
1	566	3
1	566	4
1	566	5
1	566	7
1	566	9
1	566	10
1	566	11
1	566	14
1	566	15
1	566	16
1	566	17
1	566	19
1	566	20
1	566	21
1	567	1
1	567	2
1	567	5
1	567	7
1	567	8
1	567	9
1	567	10
1	567	12
1	567	13
1	567	14
1	567	15
1	567	17
1	567	21
1	567	24
1	567	25
1	568	1
1	568	2
1	568	4
1	568	5
1	568	6
1	568	7
1	568	8
1	568	9
1	568	13
1	568	15
1	568	16
1	568	17
1	568	18
1	568	20
1	568	21
1	569	1
1	569	2
1	569	6
1	569	7
1	569	8
1	569	12
1	569	13
1	569	16
1	569	17
1	569	18
1	569	19
1	569	20
1	569	22
1	569	24
1	569	25
1	570	1
1	570	2
1	570	3
1	570	4
1	570	5
1	570	10
1	570	12
1	570	14
1	570	15
1	570	18
1	570	19
1	570	20
1	570	21
1	570	22
1	570	23
1	571	3
1	571	4
1	571	5
1	571	6
1	571	7
1	571	11
1	571	12
1	571	15
1	571	16
1	571	18
1	571	19
1	571	20
1	571	21
1	571	24
1	571	25
1	572	2
1	572	5
1	572	6
1	572	8
1	572	9
1	572	10
1	572	13
1	572	14
1	572	15
1	572	16
1	572	17
1	572	19
1	572	21
1	572	22
1	572	24
1	573	1
1	573	2
1	573	3
1	573	7
1	573	10
1	573	11
1	573	12
1	573	14
1	573	16
1	573	18
1	573	20
1	573	22
1	573	23
1	573	24
1	573	25
1	574	1
1	574	5
1	574	6
1	574	11
1	574	12
1	574	13
1	574	14
1	574	16
1	574	18
1	574	19
1	574	20
1	574	21
1	574	22
1	574	23
1	574	25
1	575	3
1	575	5
1	575	8
1	575	9
1	575	10
1	575	12
1	575	13
1	575	15
1	575	16
1	575	17
1	575	18
1	575	19
1	575	21
1	575	22
1	575	24
1	576	6
1	576	8
1	576	9
1	576	10
1	576	11
1	576	12
1	576	13
1	576	15
1	576	16
1	576	17
1	576	18
1	576	19
1	576	21
1	576	23
1	576	25
1	577	1
1	577	2
1	577	3
1	577	4
1	577	5
1	577	8
1	577	10
1	577	12
1	577	15
1	577	16
1	577	18
1	577	19
1	577	21
1	577	22
1	577	23
1	578	1
1	578	4
1	578	6
1	578	7
1	578	8
1	578	10
1	578	12
1	578	13
1	578	14
1	578	15
1	578	16
1	578	19
1	578	21
1	578	22
1	578	23
1	579	1
1	579	3
1	579	5
1	579	6
1	579	7
1	579	8
1	579	10
1	579	12
1	579	13
1	579	14
1	579	17
1	579	19
1	579	20
1	579	21
1	579	24
1	580	1
1	580	4
1	580	6
1	580	7
1	580	8
1	580	9
1	580	10
1	580	12
1	580	13
1	580	14
1	580	16
1	580	17
1	580	21
1	580	24
1	580	25
1	581	2
1	581	4
1	581	6
1	581	9
1	581	11
1	581	12
1	581	13
1	581	14
1	581	15
1	581	17
1	581	18
1	581	19
1	581	21
1	581	23
1	581	25
1	582	3
1	582	7
1	582	8
1	582	9
1	582	10
1	582	11
1	582	12
1	582	13
1	582	15
1	582	17
1	582	18
1	582	19
1	582	21
1	582	23
1	582	25
1	583	1
1	583	3
1	583	4
1	583	7
1	583	8
1	583	9
1	583	11
1	583	14
1	583	16
1	583	17
1	583	18
1	583	19
1	583	21
1	583	23
1	583	24
1	584	2
1	584	3
1	584	5
1	584	6
1	584	7
1	584	8
1	584	10
1	584	11
1	584	14
1	584	15
1	584	19
1	584	20
1	584	21
1	584	22
1	584	23
1	585	1
1	585	5
1	585	7
1	585	8
1	585	9
1	585	10
1	585	13
1	585	14
1	585	15
1	585	16
1	585	17
1	585	18
1	585	20
1	585	23
1	585	24
1	586	2
1	586	3
1	586	4
1	586	6
1	586	7
1	586	8
1	586	11
1	586	12
1	586	16
1	586	17
1	586	18
1	586	19
1	586	22
1	586	24
1	586	25
1	587	1
1	587	4
1	587	5
1	587	7
1	587	9
1	587	10
1	587	11
1	587	12
1	587	13
1	587	17
1	587	18
1	587	19
1	587	20
1	587	21
1	587	23
1	588	1
1	588	4
1	588	5
1	588	7
1	588	11
1	588	12
1	588	13
1	588	14
1	588	17
1	588	18
1	588	19
1	588	20
1	588	23
1	588	24
1	588	25
1	589	2
1	589	3
1	589	4
1	589	6
1	589	8
1	589	9
1	589	10
1	589	12
1	589	13
1	589	20
1	589	21
1	589	22
1	589	23
1	589	24
1	589	25
1	590	1
1	590	3
1	590	4
1	590	6
1	590	9
1	590	10
1	590	11
1	590	13
1	590	14
1	590	15
1	590	16
1	590	18
1	590	19
1	590	20
1	590	21
1	591	1
1	591	2
1	591	4
1	591	7
1	591	8
1	591	10
1	591	11
1	591	14
1	591	15
1	591	16
1	591	17
1	591	19
1	591	20
1	591	21
1	591	23
1	592	1
1	592	3
1	592	5
1	592	6
1	592	8
1	592	9
1	592	10
1	592	14
1	592	15
1	592	16
1	592	17
1	592	18
1	592	19
1	592	20
1	592	22
1	593	1
1	593	3
1	593	4
1	593	5
1	593	6
1	593	9
1	593	10
1	593	11
1	593	13
1	593	14
1	593	15
1	593	20
1	593	23
1	593	24
1	593	25
1	594	2
1	594	3
1	594	6
1	594	7
1	594	9
1	594	10
1	594	11
1	594	13
1	594	14
1	594	15
1	594	16
1	594	18
1	594	20
1	594	23
1	594	25
1	595	1
1	595	5
1	595	6
1	595	7
1	595	8
1	595	9
1	595	10
1	595	11
1	595	12
1	595	15
1	595	17
1	595	19
1	595	21
1	595	24
1	595	25
1	596	2
1	596	3
1	596	7
1	596	8
1	596	9
1	596	10
1	596	11
1	596	12
1	596	17
1	596	18
1	596	19
1	596	20
1	596	22
1	596	23
1	596	25
1	597	1
1	597	2
1	597	3
1	597	5
1	597	8
1	597	9
1	597	10
1	597	11
1	597	14
1	597	16
1	597	17
1	597	18
1	597	22
1	597	24
1	597	25
1	598	1
1	598	3
1	598	4
1	598	5
1	598	7
1	598	11
1	598	12
1	598	14
1	598	15
1	598	18
1	598	19
1	598	20
1	598	21
1	598	22
1	598	25
1	599	2
1	599	4
1	599	5
1	599	6
1	599	7
1	599	9
1	599	12
1	599	13
1	599	16
1	599	18
1	599	20
1	599	21
1	599	22
1	599	23
1	599	24
1	600	1
1	600	3
1	600	5
1	600	6
1	600	8
1	600	9
1	600	10
1	600	11
1	600	16
1	600	17
1	600	18
1	600	19
1	600	22
1	600	23
1	600	25
1	601	1
1	601	3
1	601	5
1	601	6
1	601	7
1	601	9
1	601	10
1	601	11
1	601	12
1	601	13
1	601	14
1	601	16
1	601	19
1	601	20
1	601	25
1	602	1
1	602	2
1	602	5
1	602	6
1	602	7
1	602	8
1	602	9
1	602	10
1	602	11
1	602	12
1	602	13
1	602	18
1	602	22
1	602	23
1	602	25
1	603	2
1	603	4
1	603	5
1	603	6
1	603	8
1	603	10
1	603	12
1	603	13
1	603	15
1	603	16
1	603	19
1	603	20
1	603	21
1	603	22
1	603	23
1	604	1
1	604	2
1	604	6
1	604	7
1	604	9
1	604	12
1	604	13
1	604	14
1	604	15
1	604	18
1	604	19
1	604	20
1	604	22
1	604	24
1	604	25
1	605	2
1	605	3
1	605	4
1	605	5
1	605	7
1	605	10
1	605	11
1	605	13
1	605	14
1	605	16
1	605	17
1	605	18
1	605	21
1	605	23
1	605	25
1	606	2
1	606	3
1	606	6
1	606	7
1	606	8
1	606	10
1	606	12
1	606	14
1	606	15
1	606	16
1	606	18
1	606	22
1	606	23
1	606	24
1	606	25
1	607	3
1	607	5
1	607	7
1	607	9
1	607	12
1	607	15
1	607	16
1	607	17
1	607	18
1	607	19
1	607	20
1	607	21
1	607	22
1	607	24
1	607	25
1	608	1
1	608	2
1	608	3
1	608	5
1	608	7
1	608	8
1	608	10
1	608	13
1	608	14
1	608	16
1	608	17
1	608	18
1	608	19
1	608	23
1	608	25
1	609	1
1	609	2
1	609	4
1	609	7
1	609	9
1	609	10
1	609	11
1	609	12
1	609	14
1	609	15
1	609	16
1	609	19
1	609	20
1	609	23
1	609	25
1	610	1
1	610	2
1	610	4
1	610	6
1	610	7
1	610	8
1	610	10
1	610	12
1	610	13
1	610	14
1	610	15
1	610	16
1	610	21
1	610	22
1	610	25
1	611	2
1	611	3
1	611	4
1	611	5
1	611	6
1	611	8
1	611	9
1	611	13
1	611	14
1	611	16
1	611	18
1	611	19
1	611	20
1	611	21
1	611	23
1	612	1
1	612	2
1	612	3
1	612	6
1	612	7
1	612	9
1	612	10
1	612	13
1	612	15
1	612	16
1	612	17
1	612	18
1	612	19
1	612	23
1	612	25
1	613	2
1	613	5
1	613	6
1	613	7
1	613	10
1	613	11
1	613	12
1	613	13
1	613	14
1	613	16
1	613	17
1	613	20
1	613	22
1	613	23
1	613	25
1	614	1
1	614	5
1	614	6
1	614	7
1	614	9
1	614	11
1	614	12
1	614	13
1	614	16
1	614	17
1	614	18
1	614	19
1	614	20
1	614	22
1	614	23
1	615	1
1	615	2
1	615	4
1	615	7
1	615	8
1	615	11
1	615	12
1	615	17
1	615	19
1	615	20
1	615	21
1	615	22
1	615	23
1	615	24
1	615	25
1	616	1
1	616	2
1	616	6
1	616	9
1	616	10
1	616	12
1	616	15
1	616	16
1	616	17
1	616	18
1	616	19
1	616	21
1	616	22
1	616	24
1	616	25
1	617	1
1	617	2
1	617	3
1	617	4
1	617	5
1	617	7
1	617	10
1	617	14
1	617	15
1	617	16
1	617	19
1	617	21
1	617	22
1	617	24
1	617	25
1	618	1
1	618	2
1	618	4
1	618	5
1	618	6
1	618	7
1	618	9
1	618	12
1	618	13
1	618	17
1	618	19
1	618	20
1	618	21
1	618	22
1	618	24
1	619	1
1	619	3
1	619	4
1	619	7
1	619	8
1	619	9
1	619	13
1	619	14
1	619	17
1	619	18
1	619	19
1	619	20
1	619	21
1	619	23
1	619	25
1	620	1
1	620	5
1	620	6
1	620	7
1	620	10
1	620	11
1	620	12
1	620	14
1	620	15
1	620	16
1	620	18
1	620	19
1	620	20
1	620	21
1	620	22
1	621	1
1	621	2
1	621	3
1	621	5
1	621	6
1	621	8
1	621	9
1	621	10
1	621	12
1	621	15
1	621	16
1	621	20
1	621	22
1	621	24
1	621	25
1	622	2
1	622	3
1	622	4
1	622	5
1	622	6
1	622	7
1	622	9
1	622	10
1	622	11
1	622	12
1	622	13
1	622	15
1	622	17
1	622	18
1	622	21
1	623	1
1	623	2
1	623	3
1	623	4
1	623	5
1	623	8
1	623	9
1	623	10
1	623	11
1	623	12
1	623	15
1	623	20
1	623	22
1	623	23
1	623	25
1	624	1
1	624	2
1	624	4
1	624	5
1	624	6
1	624	7
1	624	9
1	624	11
1	624	12
1	624	16
1	624	17
1	624	18
1	624	20
1	624	21
1	624	24
1	625	1
1	625	2
1	625	3
1	625	6
1	625	8
1	625	10
1	625	11
1	625	13
1	625	14
1	625	15
1	625	16
1	625	17
1	625	22
1	625	23
1	625	24
1	626	1
1	626	2
1	626	3
1	626	4
1	626	5
1	626	7
1	626	8
1	626	9
1	626	11
1	626	13
1	626	17
1	626	19
1	626	21
1	626	23
1	626	24
1	627	1
1	627	2
1	627	3
1	627	4
1	627	6
1	627	10
1	627	12
1	627	14
1	627	15
1	627	17
1	627	21
1	627	22
1	627	23
1	627	24
1	627	25
1	628	2
1	628	3
1	628	4
1	628	7
1	628	8
1	628	9
1	628	10
1	628	11
1	628	13
1	628	15
1	628	18
1	628	19
1	628	22
1	628	23
1	628	25
1	629	1
1	629	2
1	629	4
1	629	5
1	629	6
1	629	7
1	629	9
1	629	12
1	629	14
1	629	15
1	629	17
1	629	19
1	629	21
1	629	22
1	629	25
1	630	1
1	630	2
1	630	4
1	630	6
1	630	7
1	630	12
1	630	13
1	630	14
1	630	17
1	630	18
1	630	20
1	630	22
1	630	23
1	630	24
1	630	25
1	631	2
1	631	3
1	631	5
1	631	7
1	631	8
1	631	9
1	631	10
1	631	13
1	631	14
1	631	16
1	631	17
1	631	18
1	631	19
1	631	20
1	631	21
1	632	1
1	632	4
1	632	6
1	632	8
1	632	10
1	632	11
1	632	13
1	632	14
1	632	16
1	632	17
1	632	20
1	632	21
1	632	22
1	632	24
1	632	25
1	633	2
1	633	3
1	633	6
1	633	7
1	633	8
1	633	9
1	633	10
1	633	12
1	633	18
1	633	20
1	633	21
1	633	22
1	633	23
1	633	24
1	633	25
1	634	2
1	634	3
1	634	4
1	634	5
1	634	9
1	634	10
1	634	11
1	634	12
1	634	14
1	634	15
1	634	18
1	634	19
1	634	20
1	634	21
1	634	22
1	635	1
1	635	4
1	635	5
1	635	6
1	635	7
1	635	8
1	635	9
1	635	11
1	635	12
1	635	13
1	635	18
1	635	19
1	635	20
1	635	22
1	635	24
1	636	1
1	636	2
1	636	3
1	636	4
1	636	6
1	636	10
1	636	12
1	636	13
1	636	14
1	636	16
1	636	19
1	636	20
1	636	21
1	636	23
1	636	25
1	637	2
1	637	4
1	637	6
1	637	7
1	637	9
1	637	13
1	637	16
1	637	17
1	637	18
1	637	19
1	637	20
1	637	21
1	637	22
1	637	23
1	637	25
1	638	1
1	638	2
1	638	3
1	638	4
1	638	9
1	638	11
1	638	13
1	638	14
1	638	16
1	638	18
1	638	19
1	638	21
1	638	23
1	638	24
1	638	25
1	639	1
1	639	2
1	639	4
1	639	5
1	639	6
1	639	8
1	639	9
1	639	10
1	639	12
1	639	16
1	639	19
1	639	20
1	639	21
1	639	22
1	639	24
1	640	1
1	640	3
1	640	4
1	640	5
1	640	9
1	640	11
1	640	13
1	640	14
1	640	16
1	640	18
1	640	19
1	640	20
1	640	21
1	640	22
1	640	23
1	641	2
1	641	3
1	641	6
1	641	7
1	641	8
1	641	9
1	641	11
1	641	13
1	641	16
1	641	18
1	641	19
1	641	20
1	641	21
1	641	22
1	641	24
1	642	1
1	642	2
1	642	4
1	642	5
1	642	8
1	642	10
1	642	11
1	642	12
1	642	13
1	642	18
1	642	19
1	642	20
1	642	21
1	642	22
1	642	25
1	643	1
1	643	2
1	643	4
1	643	7
1	643	8
1	643	9
1	643	10
1	643	13
1	643	16
1	643	17
1	643	19
1	643	21
1	643	22
1	643	23
1	643	24
1	644	2
1	644	3
1	644	5
1	644	6
1	644	7
1	644	8
1	644	9
1	644	12
1	644	13
1	644	14
1	644	15
1	644	18
1	644	21
1	644	22
1	644	24
1	645	4
1	645	5
1	645	8
1	645	9
1	645	10
1	645	11
1	645	13
1	645	16
1	645	18
1	645	19
1	645	20
1	645	21
1	645	22
1	645	23
1	645	25
1	646	1
1	646	3
1	646	5
1	646	6
1	646	9
1	646	10
1	646	14
1	646	15
1	646	17
1	646	18
1	646	19
1	646	20
1	646	21
1	646	23
1	646	25
1	647	4
1	647	6
1	647	7
1	647	8
1	647	9
1	647	11
1	647	13
1	647	14
1	647	17
1	647	18
1	647	19
1	647	20
1	647	22
1	647	23
1	647	25
1	648	2
1	648	4
1	648	6
1	648	8
1	648	9
1	648	10
1	648	11
1	648	13
1	648	15
1	648	16
1	648	18
1	648	19
1	648	20
1	648	21
1	648	22
1	649	1
1	649	2
1	649	4
1	649	5
1	649	6
1	649	8
1	649	9
1	649	10
1	649	11
1	649	14
1	649	15
1	649	17
1	649	21
1	649	22
1	649	24
1	650	1
1	650	3
1	650	7
1	650	8
1	650	10
1	650	13
1	650	14
1	650	16
1	650	17
1	650	19
1	650	20
1	650	21
1	650	23
1	650	24
1	650	25
1	651	1
1	651	4
1	651	5
1	651	6
1	651	8
1	651	10
1	651	13
1	651	14
1	651	15
1	651	17
1	651	18
1	651	19
1	651	20
1	651	24
1	651	25
1	652	2
1	652	5
1	652	7
1	652	9
1	652	10
1	652	11
1	652	13
1	652	14
1	652	16
1	652	17
1	652	18
1	652	19
1	652	20
1	652	21
1	652	23
1	653	1
1	653	2
1	653	3
1	653	7
1	653	8
1	653	12
1	653	13
1	653	14
1	653	16
1	653	17
1	653	19
1	653	20
1	653	21
1	653	22
1	653	23
1	654	1
1	654	2
1	654	3
1	654	7
1	654	12
1	654	13
1	654	14
1	654	16
1	654	17
1	654	18
1	654	19
1	654	20
1	654	22
1	654	23
1	654	25
1	655	2
1	655	5
1	655	7
1	655	8
1	655	10
1	655	11
1	655	13
1	655	14
1	655	15
1	655	19
1	655	20
1	655	21
1	655	23
1	655	24
1	655	25
1	656	2
1	656	3
1	656	5
1	656	7
1	656	8
1	656	9
1	656	11
1	656	13
1	656	14
1	656	15
1	656	18
1	656	20
1	656	22
1	656	23
1	656	25
1	657	2
1	657	3
1	657	4
1	657	5
1	657	6
1	657	8
1	657	10
1	657	12
1	657	13
1	657	15
1	657	17
1	657	19
1	657	23
1	657	24
1	657	25
1	658	1
1	658	4
1	658	5
1	658	6
1	658	7
1	658	9
1	658	10
1	658	11
1	658	14
1	658	15
1	658	17
1	658	21
1	658	23
1	658	24
1	658	25
1	659	1
1	659	3
1	659	4
1	659	5
1	659	6
1	659	8
1	659	9
1	659	10
1	659	11
1	659	12
1	659	15
1	659	19
1	659	20
1	659	23
1	659	24
1	660	3
1	660	4
1	660	5
1	660	6
1	660	7
1	660	8
1	660	9
1	660	12
1	660	14
1	660	15
1	660	16
1	660	17
1	660	19
1	660	24
1	660	25
1	661	1
1	661	3
1	661	6
1	661	7
1	661	10
1	661	11
1	661	12
1	661	15
1	661	17
1	661	18
1	661	19
1	661	20
1	661	22
1	661	23
1	661	24
1	662	1
1	662	2
1	662	3
1	662	6
1	662	7
1	662	8
1	662	9
1	662	11
1	662	13
1	662	14
1	662	15
1	662	16
1	662	19
1	662	20
1	662	22
1	663	2
1	663	4
1	663	5
1	663	6
1	663	7
1	663	9
1	663	11
1	663	13
1	663	16
1	663	17
1	663	19
1	663	21
1	663	22
1	663	23
1	663	24
1	664	1
1	664	3
1	664	4
1	664	7
1	664	10
1	664	13
1	664	14
1	664	15
1	664	16
1	664	17
1	664	18
1	664	20
1	664	21
1	664	23
1	664	24
1	665	2
1	665	3
1	665	6
1	665	7
1	665	12
1	665	13
1	665	14
1	665	15
1	665	17
1	665	18
1	665	20
1	665	21
1	665	22
1	665	24
1	665	25
1	666	1
1	666	2
1	666	4
1	666	6
1	666	7
1	666	11
1	666	12
1	666	14
1	666	15
1	666	16
1	666	18
1	666	20
1	666	21
1	666	24
1	666	25
1	667	3
1	667	4
1	667	5
1	667	6
1	667	8
1	667	10
1	667	13
1	667	15
1	667	17
1	667	18
1	667	19
1	667	20
1	667	21
1	667	24
1	667	25
1	668	1
1	668	2
1	668	7
1	668	9
1	668	10
1	668	11
1	668	12
1	668	13
1	668	15
1	668	16
1	668	17
1	668	20
1	668	23
1	668	24
1	668	25
1	669	2
1	669	4
1	669	5
1	669	6
1	669	12
1	669	13
1	669	15
1	669	16
1	669	17
1	669	18
1	669	19
1	669	22
1	669	23
1	669	24
1	669	25
1	670	1
1	670	7
1	670	8
1	670	10
1	670	12
1	670	13
1	670	14
1	670	15
1	670	17
1	670	18
1	670	20
1	670	21
1	670	22
1	670	23
1	670	25
1	671	4
1	671	5
1	671	7
1	671	8
1	671	9
1	671	10
1	671	11
1	671	12
1	671	13
1	671	14
1	671	18
1	671	19
1	671	20
1	671	22
1	671	24
1	672	1
1	672	2
1	672	4
1	672	6
1	672	9
1	672	10
1	672	11
1	672	12
1	672	15
1	672	17
1	672	19
1	672	21
1	672	23
1	672	24
1	672	25
1	673	2
1	673	4
1	673	5
1	673	7
1	673	8
1	673	9
1	673	10
1	673	11
1	673	12
1	673	13
1	673	14
1	673	15
1	673	17
1	673	19
1	673	20
1	674	2
1	674	3
1	674	8
1	674	10
1	674	11
1	674	14
1	674	15
1	674	16
1	674	18
1	674	19
1	674	20
1	674	22
1	674	23
1	674	24
1	674	25
1	675	2
1	675	3
1	675	4
1	675	5
1	675	7
1	675	10
1	675	11
1	675	13
1	675	14
1	675	15
1	675	16
1	675	17
1	675	22
1	675	23
1	675	24
1	676	2
1	676	4
1	676	5
1	676	6
1	676	8
1	676	10
1	676	12
1	676	13
1	676	15
1	676	16
1	676	19
1	676	20
1	676	21
1	676	24
1	676	25
1	677	1
1	677	2
1	677	5
1	677	6
1	677	7
1	677	8
1	677	10
1	677	11
1	677	12
1	677	13
1	677	15
1	677	16
1	677	19
1	677	23
1	677	25
1	678	2
1	678	3
1	678	5
1	678	7
1	678	9
1	678	10
1	678	12
1	678	15
1	678	18
1	678	19
1	678	20
1	678	21
1	678	23
1	678	24
1	678	25
1	679	2
1	679	7
1	679	8
1	679	10
1	679	11
1	679	12
1	679	13
1	679	14
1	679	15
1	679	17
1	679	18
1	679	19
1	679	20
1	679	21
1	679	22
1	680	3
1	680	4
1	680	6
1	680	7
1	680	8
1	680	9
1	680	12
1	680	13
1	680	14
1	680	16
1	680	18
1	680	19
1	680	20
1	680	21
1	680	22
1	681	2
1	681	3
1	681	4
1	681	6
1	681	7
1	681	8
1	681	10
1	681	11
1	681	12
1	681	14
1	681	15
1	681	16
1	681	18
1	681	19
1	681	23
1	682	1
1	682	2
1	682	4
1	682	5
1	682	6
1	682	7
1	682	8
1	682	11
1	682	14
1	682	17
1	682	18
1	682	19
1	682	22
1	682	24
1	682	25
1	683	1
1	683	2
1	683	4
1	683	5
1	683	6
1	683	7
1	683	8
1	683	9
1	683	10
1	683	11
1	683	12
1	683	13
1	683	15
1	683	23
1	683	24
1	684	1
1	684	4
1	684	5
1	684	8
1	684	10
1	684	11
1	684	12
1	684	13
1	684	14
1	684	16
1	684	20
1	684	21
1	684	22
1	684	24
1	684	25
1	685	1
1	685	3
1	685	4
1	685	9
1	685	12
1	685	13
1	685	15
1	685	17
1	685	19
1	685	20
1	685	21
1	685	22
1	685	23
1	685	24
1	685	25
1	686	1
1	686	3
1	686	4
1	686	6
1	686	7
1	686	10
1	686	12
1	686	13
1	686	16
1	686	19
1	686	20
1	686	22
1	686	23
1	686	24
1	686	25
1	687	1
1	687	2
1	687	3
1	687	4
1	687	6
1	687	9
1	687	12
1	687	13
1	687	15
1	687	18
1	687	19
1	687	20
1	687	23
1	687	24
1	687	25
1	688	1
1	688	2
1	688	3
1	688	4
1	688	7
1	688	9
1	688	11
1	688	12
1	688	14
1	688	16
1	688	19
1	688	21
1	688	22
1	688	23
1	688	24
1	689	2
1	689	3
1	689	4
1	689	5
1	689	6
1	689	7
1	689	8
1	689	11
1	689	12
1	689	13
1	689	15
1	689	17
1	689	22
1	689	23
1	689	24
1	690	1
1	690	2
1	690	3
1	690	9
1	690	10
1	690	11
1	690	12
1	690	13
1	690	14
1	690	15
1	690	18
1	690	19
1	690	20
1	690	24
1	690	25
1	691	1
1	691	2
1	691	3
1	691	6
1	691	7
1	691	8
1	691	9
1	691	11
1	691	13
1	691	17
1	691	18
1	691	19
1	691	20
1	691	22
1	691	23
1	692	1
1	692	2
1	692	4
1	692	6
1	692	7
1	692	10
1	692	11
1	692	12
1	692	17
1	692	18
1	692	19
1	692	21
1	692	22
1	692	23
1	692	24
1	693	1
1	693	2
1	693	3
1	693	4
1	693	6
1	693	7
1	693	9
1	693	10
1	693	11
1	693	14
1	693	16
1	693	17
1	693	19
1	693	21
1	693	22
1	694	1
1	694	3
1	694	6
1	694	8
1	694	9
1	694	10
1	694	11
1	694	14
1	694	15
1	694	16
1	694	18
1	694	19
1	694	20
1	694	21
1	694	24
1	695	2
1	695	3
1	695	4
1	695	5
1	695	11
1	695	13
1	695	14
1	695	17
1	695	18
1	695	19
1	695	20
1	695	21
1	695	22
1	695	24
1	695	25
1	696	1
1	696	4
1	696	5
1	696	7
1	696	9
1	696	10
1	696	11
1	696	13
1	696	14
1	696	15
1	696	16
1	696	20
1	696	21
1	696	22
1	696	24
1	697	1
1	697	2
1	697	3
1	697	7
1	697	8
1	697	11
1	697	14
1	697	15
1	697	16
1	697	18
1	697	19
1	697	22
1	697	23
1	697	24
1	697	25
1	698	2
1	698	3
1	698	4
1	698	6
1	698	7
1	698	9
1	698	10
1	698	12
1	698	14
1	698	15
1	698	18
1	698	20
1	698	21
1	698	22
1	698	24
1	699	2
1	699	3
1	699	4
1	699	6
1	699	8
1	699	9
1	699	10
1	699	15
1	699	16
1	699	18
1	699	19
1	699	21
1	699	22
1	699	23
1	699	25
1	700	1
1	700	2
1	700	6
1	700	7
1	700	8
1	700	9
1	700	10
1	700	13
1	700	14
1	700	16
1	700	18
1	700	19
1	700	21
1	700	22
1	700	25
1	701	3
1	701	4
1	701	8
1	701	10
1	701	12
1	701	13
1	701	14
1	701	16
1	701	17
1	701	19
1	701	20
1	701	21
1	701	22
1	701	23
1	701	25
1	702	1
1	702	2
1	702	3
1	702	4
1	702	5
1	702	6
1	702	7
1	702	8
1	702	9
1	702	10
1	702	13
1	702	14
1	702	20
1	702	23
1	702	25
1	703	2
1	703	5
1	703	8
1	703	10
1	703	11
1	703	14
1	703	15
1	703	17
1	703	18
1	703	20
1	703	21
1	703	22
1	703	23
1	703	24
1	703	25
1	704	2
1	704	3
1	704	5
1	704	6
1	704	8
1	704	10
1	704	11
1	704	13
1	704	14
1	704	15
1	704	16
1	704	17
1	704	22
1	704	23
1	704	24
1	705	3
1	705	4
1	705	6
1	705	7
1	705	8
1	705	9
1	705	11
1	705	12
1	705	14
1	705	15
1	705	16
1	705	20
1	705	21
1	705	22
1	705	25
1	706	1
1	706	2
1	706	3
1	706	4
1	706	6
1	706	8
1	706	12
1	706	13
1	706	16
1	706	18
1	706	19
1	706	21
1	706	22
1	706	24
1	706	25
1	707	3
1	707	4
1	707	6
1	707	7
1	707	8
1	707	11
1	707	12
1	707	14
1	707	15
1	707	16
1	707	17
1	707	20
1	707	21
1	707	24
1	707	25
1	708	1
1	708	2
1	708	3
1	708	4
1	708	5
1	708	6
1	708	9
1	708	11
1	708	14
1	708	16
1	708	19
1	708	21
1	708	22
1	708	24
1	708	25
1	709	1
1	709	3
1	709	6
1	709	7
1	709	8
1	709	11
1	709	12
1	709	14
1	709	15
1	709	16
1	709	18
1	709	19
1	709	20
1	709	22
1	709	23
1	710	2
1	710	3
1	710	4
1	710	6
1	710	12
1	710	14
1	710	15
1	710	17
1	710	18
1	710	19
1	710	20
1	710	21
1	710	22
1	710	24
1	710	25
1	711	1
1	711	2
1	711	4
1	711	5
1	711	6
1	711	7
1	711	10
1	711	12
1	711	13
1	711	15
1	711	16
1	711	18
1	711	21
1	711	22
1	711	24
1	712	1
1	712	4
1	712	8
1	712	9
1	712	12
1	712	14
1	712	15
1	712	16
1	712	17
1	712	18
1	712	20
1	712	21
1	712	22
1	712	23
1	712	25
1	713	2
1	713	3
1	713	4
1	713	5
1	713	6
1	713	11
1	713	13
1	713	14
1	713	15
1	713	19
1	713	21
1	713	22
1	713	23
1	713	24
1	713	25
1	714	4
1	714	6
1	714	7
1	714	8
1	714	9
1	714	10
1	714	11
1	714	12
1	714	13
1	714	14
1	714	15
1	714	17
1	714	19
1	714	21
1	714	22
1	715	1
1	715	3
1	715	5
1	715	8
1	715	10
1	715	11
1	715	13
1	715	14
1	715	15
1	715	18
1	715	20
1	715	22
1	715	23
1	715	24
1	715	25
1	716	1
1	716	3
1	716	5
1	716	7
1	716	8
1	716	11
1	716	12
1	716	14
1	716	15
1	716	16
1	716	18
1	716	20
1	716	21
1	716	23
1	716	25
1	717	1
1	717	2
1	717	3
1	717	5
1	717	7
1	717	8
1	717	9
1	717	11
1	717	14
1	717	16
1	717	18
1	717	20
1	717	21
1	717	23
1	717	25
1	718	3
1	718	4
1	718	7
1	718	9
1	718	11
1	718	13
1	718	14
1	718	15
1	718	17
1	718	19
1	718	21
1	718	22
1	718	23
1	718	24
1	718	25
1	719	2
1	719	7
1	719	8
1	719	9
1	719	10
1	719	11
1	719	13
1	719	15
1	719	16
1	719	18
1	719	19
1	719	22
1	719	23
1	719	24
1	719	25
1	720	4
1	720	7
1	720	9
1	720	10
1	720	11
1	720	12
1	720	13
1	720	16
1	720	17
1	720	18
1	720	20
1	720	21
1	720	23
1	720	24
1	720	25
1	721	1
1	721	2
1	721	3
1	721	4
1	721	5
1	721	7
1	721	8
1	721	9
1	721	10
1	721	11
1	721	12
1	721	14
1	721	15
1	721	19
1	721	21
1	722	1
1	722	3
1	722	5
1	722	6
1	722	7
1	722	8
1	722	10
1	722	13
1	722	14
1	722	16
1	722	17
1	722	19
1	722	20
1	722	23
1	722	24
1	723	2
1	723	3
1	723	4
1	723	5
1	723	7
1	723	8
1	723	9
1	723	10
1	723	11
1	723	12
1	723	14
1	723	15
1	723	18
1	723	20
1	723	24
1	724	1
1	724	3
1	724	5
1	724	6
1	724	7
1	724	10
1	724	12
1	724	14
1	724	15
1	724	18
1	724	19
1	724	20
1	724	23
1	724	24
1	724	25
1	725	1
1	725	5
1	725	6
1	725	7
1	725	9
1	725	10
1	725	12
1	725	13
1	725	15
1	725	16
1	725	17
1	725	18
1	725	21
1	725	24
1	725	25
1	726	1
1	726	2
1	726	4
1	726	7
1	726	9
1	726	10
1	726	11
1	726	13
1	726	14
1	726	15
1	726	16
1	726	20
1	726	21
1	726	24
1	726	25
1	727	3
1	727	4
1	727	6
1	727	7
1	727	8
1	727	9
1	727	11
1	727	16
1	727	18
1	727	20
1	727	21
1	727	22
1	727	23
1	727	24
1	727	25
1	728	3
1	728	4
1	728	6
1	728	7
1	728	8
1	728	10
1	728	11
1	728	13
1	728	16
1	728	19
1	728	20
1	728	21
1	728	22
1	728	23
1	728	25
1	729	1
1	729	2
1	729	3
1	729	4
1	729	6
1	729	7
1	729	9
1	729	10
1	729	12
1	729	14
1	729	15
1	729	17
1	729	22
1	729	23
1	729	25
1	730	1
1	730	3
1	730	4
1	730	8
1	730	11
1	730	12
1	730	14
1	730	16
1	730	18
1	730	19
1	730	20
1	730	21
1	730	22
1	730	24
1	730	25
1	731	3
1	731	4
1	731	6
1	731	7
1	731	8
1	731	11
1	731	12
1	731	14
1	731	15
1	731	17
1	731	18
1	731	19
1	731	21
1	731	22
1	731	24
1	732	1
1	732	4
1	732	8
1	732	9
1	732	10
1	732	11
1	732	13
1	732	14
1	732	17
1	732	20
1	732	21
1	732	22
1	732	23
1	732	24
1	732	25
1	733	1
1	733	4
1	733	5
1	733	6
1	733	7
1	733	8
1	733	11
1	733	12
1	733	14
1	733	16
1	733	18
1	733	19
1	733	20
1	733	22
1	733	24
1	734	2
1	734	3
1	734	6
1	734	8
1	734	9
1	734	10
1	734	13
1	734	15
1	734	17
1	734	18
1	734	19
1	734	20
1	734	21
1	734	23
1	734	24
1	735	5
1	735	6
1	735	8
1	735	10
1	735	11
1	735	12
1	735	13
1	735	14
1	735	17
1	735	19
1	735	20
1	735	21
1	735	22
1	735	24
1	735	25
1	736	2
1	736	3
1	736	4
1	736	5
1	736	6
1	736	8
1	736	9
1	736	10
1	736	13
1	736	15
1	736	16
1	736	17
1	736	19
1	736	21
1	736	23
1	737	2
1	737	3
1	737	4
1	737	5
1	737	6
1	737	7
1	737	8
1	737	10
1	737	12
1	737	14
1	737	16
1	737	17
1	737	18
1	737	22
1	737	25
1	738	2
1	738	6
1	738	7
1	738	9
1	738	11
1	738	12
1	738	13
1	738	14
1	738	16
1	738	18
1	738	19
1	738	20
1	738	23
1	738	24
1	738	25
1	739	2
1	739	3
1	739	4
1	739	8
1	739	9
1	739	10
1	739	11
1	739	14
1	739	17
1	739	20
1	739	21
1	739	22
1	739	23
1	739	24
1	739	25
1	740	1
1	740	4
1	740	5
1	740	9
1	740	10
1	740	11
1	740	12
1	740	13
1	740	14
1	740	19
1	740	21
1	740	22
1	740	23
1	740	24
1	740	25
1	741	2
1	741	3
1	741	5
1	741	7
1	741	10
1	741	11
1	741	12
1	741	13
1	741	14
1	741	16
1	741	17
1	741	18
1	741	21
1	741	24
1	741	25
1	742	1
1	742	3
1	742	5
1	742	6
1	742	7
1	742	8
1	742	9
1	742	11
1	742	13
1	742	14
1	742	15
1	742	19
1	742	20
1	742	21
1	742	23
1	743	1
1	743	2
1	743	3
1	743	6
1	743	9
1	743	10
1	743	11
1	743	12
1	743	14
1	743	15
1	743	17
1	743	21
1	743	22
1	743	23
1	743	24
1	744	1
1	744	3
1	744	4
1	744	6
1	744	7
1	744	9
1	744	10
1	744	11
1	744	12
1	744	13
1	744	15
1	744	16
1	744	19
1	744	23
1	744	24
1	745	1
1	745	3
1	745	6
1	745	7
1	745	8
1	745	9
1	745	11
1	745	12
1	745	13
1	745	16
1	745	17
1	745	20
1	745	22
1	745	24
1	745	25
1	746	2
1	746	3
1	746	4
1	746	5
1	746	8
1	746	9
1	746	10
1	746	16
1	746	17
1	746	18
1	746	19
1	746	20
1	746	21
1	746	24
1	746	25
1	747	1
1	747	2
1	747	3
1	747	4
1	747	6
1	747	7
1	747	10
1	747	12
1	747	13
1	747	15
1	747	16
1	747	17
1	747	20
1	747	23
1	747	24
1	748	1
1	748	3
1	748	4
1	748	5
1	748	6
1	748	8
1	748	9
1	748	10
1	748	12
1	748	15
1	748	17
1	748	18
1	748	20
1	748	21
1	748	23
1	749	1
1	749	2
1	749	3
1	749	4
1	749	6
1	749	7
1	749	8
1	749	11
1	749	13
1	749	14
1	749	15
1	749	18
1	749	19
1	749	22
1	749	24
1	750	2
1	750	3
1	750	4
1	750	5
1	750	7
1	750	9
1	750	10
1	750	11
1	750	13
1	750	15
1	750	19
1	750	20
1	750	21
1	750	24
1	750	25
1	751	3
1	751	5
1	751	6
1	751	8
1	751	9
1	751	12
1	751	13
1	751	14
1	751	16
1	751	17
1	751	19
1	751	20
1	751	21
1	751	22
1	751	23
1	752	1
1	752	4
1	752	5
1	752	6
1	752	7
1	752	8
1	752	12
1	752	13
1	752	14
1	752	16
1	752	18
1	752	19
1	752	21
1	752	24
1	752	25
1	753	1
1	753	3
1	753	4
1	753	5
1	753	6
1	753	7
1	753	8
1	753	11
1	753	13
1	753	14
1	753	17
1	753	20
1	753	21
1	753	22
1	753	25
1	754	1
1	754	4
1	754	5
1	754	7
1	754	13
1	754	15
1	754	16
1	754	17
1	754	18
1	754	19
1	754	20
1	754	22
1	754	23
1	754	24
1	754	25
1	755	1
1	755	2
1	755	3
1	755	5
1	755	7
1	755	8
1	755	10
1	755	11
1	755	12
1	755	13
1	755	14
1	755	16
1	755	17
1	755	24
1	755	25
1	756	3
1	756	5
1	756	6
1	756	7
1	756	8
1	756	10
1	756	13
1	756	14
1	756	15
1	756	16
1	756	17
1	756	20
1	756	22
1	756	23
1	756	25
1	757	1
1	757	3
1	757	4
1	757	8
1	757	9
1	757	10
1	757	11
1	757	13
1	757	14
1	757	15
1	757	17
1	757	18
1	757	20
1	757	21
1	757	23
1	758	1
1	758	2
1	758	4
1	758	5
1	758	6
1	758	11
1	758	12
1	758	15
1	758	16
1	758	17
1	758	18
1	758	20
1	758	23
1	758	24
1	758	25
1	759	2
1	759	5
1	759	7
1	759	8
1	759	9
1	759	10
1	759	15
1	759	16
1	759	17
1	759	18
1	759	19
1	759	20
1	759	23
1	759	24
1	759	25
1	760	1
1	760	2
1	760	3
1	760	7
1	760	9
1	760	10
1	760	11
1	760	12
1	760	13
1	760	15
1	760	16
1	760	17
1	760	23
1	760	24
1	760	25
1	761	1
1	761	4
1	761	5
1	761	6
1	761	10
1	761	11
1	761	12
1	761	13
1	761	14
1	761	15
1	761	16
1	761	19
1	761	20
1	761	22
1	761	24
1	762	1
1	762	2
1	762	3
1	762	5
1	762	6
1	762	7
1	762	9
1	762	10
1	762	11
1	762	12
1	762	13
1	762	14
1	762	17
1	762	21
1	762	22
1	763	1
1	763	2
1	763	3
1	763	4
1	763	6
1	763	7
1	763	13
1	763	14
1	763	16
1	763	17
1	763	18
1	763	21
1	763	22
1	763	24
1	763	25
1	764	1
1	764	3
1	764	4
1	764	6
1	764	8
1	764	9
1	764	11
1	764	12
1	764	14
1	764	16
1	764	17
1	764	19
1	764	23
1	764	24
1	764	25
1	765	1
1	765	2
1	765	3
1	765	7
1	765	8
1	765	9
1	765	10
1	765	12
1	765	13
1	765	14
1	765	18
1	765	20
1	765	23
1	765	24
1	765	25
1	766	1
1	766	3
1	766	5
1	766	6
1	766	7
1	766	9
1	766	12
1	766	13
1	766	14
1	766	15
1	766	16
1	766	18
1	766	21
1	766	24
1	766	25
1	767	1
1	767	3
1	767	4
1	767	5
1	767	7
1	767	8
1	767	10
1	767	11
1	767	12
1	767	15
1	767	17
1	767	19
1	767	22
1	767	23
1	767	24
1	768	1
1	768	3
1	768	5
1	768	6
1	768	11
1	768	12
1	768	13
1	768	14
1	768	15
1	768	17
1	768	19
1	768	20
1	768	23
1	768	24
1	768	25
1	769	3
1	769	4
1	769	5
1	769	7
1	769	10
1	769	11
1	769	13
1	769	15
1	769	16
1	769	17
1	769	19
1	769	20
1	769	22
1	769	23
1	769	25
1	770	1
1	770	3
1	770	4
1	770	5
1	770	6
1	770	9
1	770	11
1	770	12
1	770	16
1	770	17
1	770	18
1	770	21
1	770	22
1	770	24
1	770	25
1	771	2
1	771	4
1	771	5
1	771	6
1	771	7
1	771	8
1	771	9
1	771	10
1	771	14
1	771	16
1	771	17
1	771	20
1	771	22
1	771	23
1	771	25
1	772	2
1	772	4
1	772	6
1	772	7
1	772	8
1	772	9
1	772	10
1	772	11
1	772	12
1	772	15
1	772	16
1	772	20
1	772	23
1	772	24
1	772	25
1	773	2
1	773	5
1	773	6
1	773	7
1	773	8
1	773	10
1	773	11
1	773	13
1	773	15
1	773	17
1	773	18
1	773	20
1	773	22
1	773	24
1	773	25
1	774	1
1	774	3
1	774	4
1	774	5
1	774	6
1	774	8
1	774	9
1	774	11
1	774	12
1	774	14
1	774	15
1	774	18
1	774	19
1	774	22
1	774	25
1	775	2
1	775	3
1	775	6
1	775	7
1	775	8
1	775	9
1	775	10
1	775	12
1	775	13
1	775	14
1	775	16
1	775	17
1	775	18
1	775	19
1	775	20
1	776	1
1	776	2
1	776	3
1	776	4
1	776	10
1	776	11
1	776	12
1	776	13
1	776	14
1	776	18
1	776	19
1	776	20
1	776	22
1	776	23
1	776	24
1	777	2
1	777	3
1	777	6
1	777	9
1	777	11
1	777	12
1	777	13
1	777	14
1	777	15
1	777	16
1	777	20
1	777	21
1	777	23
1	777	24
1	777	25
1	778	2
1	778	5
1	778	6
1	778	7
1	778	9
1	778	10
1	778	11
1	778	13
1	778	15
1	778	16
1	778	19
1	778	20
1	778	22
1	778	24
1	778	25
1	779	4
1	779	5
1	779	8
1	779	9
1	779	11
1	779	12
1	779	13
1	779	14
1	779	16
1	779	17
1	779	19
1	779	20
1	779	21
1	779	22
1	779	23
1	780	3
1	780	6
1	780	7
1	780	8
1	780	10
1	780	13
1	780	15
1	780	16
1	780	17
1	780	18
1	780	19
1	780	20
1	780	21
1	780	24
1	780	25
1	781	1
1	781	2
1	781	4
1	781	8
1	781	9
1	781	10
1	781	11
1	781	14
1	781	15
1	781	16
1	781	17
1	781	19
1	781	20
1	781	22
1	781	25
1	782	5
1	782	8
1	782	9
1	782	10
1	782	11
1	782	12
1	782	13
1	782	14
1	782	15
1	782	16
1	782	17
1	782	18
1	782	19
1	782	20
1	782	21
1	783	1
1	783	2
1	783	5
1	783	6
1	783	7
1	783	8
1	783	11
1	783	13
1	783	15
1	783	16
1	783	19
1	783	20
1	783	21
1	783	22
1	783	24
1	784	1
1	784	2
1	784	3
1	784	4
1	784	7
1	784	11
1	784	12
1	784	13
1	784	15
1	784	18
1	784	20
1	784	21
1	784	22
1	784	23
1	784	25
1	785	1
1	785	2
1	785	4
1	785	6
1	785	7
1	785	10
1	785	11
1	785	12
1	785	13
1	785	15
1	785	16
1	785	17
1	785	19
1	785	21
1	785	23
1	786	2
1	786	4
1	786	5
1	786	6
1	786	8
1	786	10
1	786	11
1	786	12
1	786	13
1	786	15
1	786	17
1	786	21
1	786	23
1	786	24
1	786	25
1	787	1
1	787	4
1	787	5
1	787	8
1	787	9
1	787	10
1	787	11
1	787	12
1	787	13
1	787	14
1	787	16
1	787	17
1	787	19
1	787	20
1	787	23
1	788	1
1	788	3
1	788	4
1	788	8
1	788	9
1	788	10
1	788	11
1	788	12
1	788	16
1	788	19
1	788	21
1	788	22
1	788	23
1	788	24
1	788	25
1	789	2
1	789	3
1	789	4
1	789	8
1	789	10
1	789	11
1	789	12
1	789	14
1	789	15
1	789	16
1	789	18
1	789	19
1	789	21
1	789	22
1	789	24
1	790	3
1	790	6
1	790	7
1	790	8
1	790	10
1	790	12
1	790	13
1	790	16
1	790	18
1	790	19
1	790	20
1	790	22
1	790	23
1	790	24
1	790	25
1	791	1
1	791	2
1	791	3
1	791	5
1	791	6
1	791	7
1	791	8
1	791	10
1	791	11
1	791	13
1	791	14
1	791	21
1	791	22
1	791	23
1	791	25
1	792	1
1	792	2
1	792	3
1	792	6
1	792	8
1	792	9
1	792	10
1	792	12
1	792	14
1	792	18
1	792	19
1	792	20
1	792	21
1	792	23
1	792	25
1	793	2
1	793	4
1	793	5
1	793	7
1	793	9
1	793	11
1	793	12
1	793	14
1	793	16
1	793	17
1	793	18
1	793	20
1	793	21
1	793	23
1	793	25
1	794	1
1	794	2
1	794	3
1	794	4
1	794	5
1	794	6
1	794	8
1	794	9
1	794	11
1	794	14
1	794	15
1	794	20
1	794	23
1	794	24
1	794	25
1	795	1
1	795	2
1	795	3
1	795	4
1	795	6
1	795	7
1	795	8
1	795	9
1	795	10
1	795	12
1	795	14
1	795	16
1	795	21
1	795	22
1	795	24
1	796	2
1	796	3
1	796	4
1	796	6
1	796	7
1	796	8
1	796	10
1	796	11
1	796	14
1	796	16
1	796	17
1	796	18
1	796	20
1	796	21
1	796	24
1	797	2
1	797	3
1	797	5
1	797	6
1	797	7
1	797	8
1	797	11
1	797	15
1	797	17
1	797	18
1	797	19
1	797	20
1	797	21
1	797	24
1	797	25
1	798	1
1	798	3
1	798	5
1	798	6
1	798	8
1	798	10
1	798	11
1	798	13
1	798	15
1	798	16
1	798	18
1	798	19
1	798	22
1	798	23
1	798	24
1	799	3
1	799	4
1	799	6
1	799	8
1	799	11
1	799	13
1	799	14
1	799	15
1	799	16
1	799	19
1	799	21
1	799	22
1	799	23
1	799	24
1	799	25
1	800	3
1	800	4
1	800	6
1	800	7
1	800	8
1	800	9
1	800	10
1	800	11
1	800	12
1	800	13
1	800	16
1	800	20
1	800	21
1	800	22
1	800	24
1	801	1
1	801	3
1	801	4
1	801	5
1	801	6
1	801	7
1	801	10
1	801	12
1	801	15
1	801	17
1	801	18
1	801	19
1	801	21
1	801	23
1	801	25
1	802	1
1	802	3
1	802	4
1	802	5
1	802	8
1	802	9
1	802	10
1	802	12
1	802	13
1	802	14
1	802	18
1	802	20
1	802	21
1	802	22
1	802	25
1	803	1
1	803	4
1	803	5
1	803	12
1	803	14
1	803	15
1	803	16
1	803	17
1	803	18
1	803	19
1	803	20
1	803	21
1	803	23
1	803	24
1	803	25
1	804	1
1	804	3
1	804	4
1	804	5
1	804	6
1	804	7
1	804	8
1	804	13
1	804	15
1	804	17
1	804	18
1	804	20
1	804	21
1	804	23
1	804	24
1	805	1
1	805	2
1	805	4
1	805	6
1	805	7
1	805	9
1	805	11
1	805	13
1	805	14
1	805	16
1	805	17
1	805	20
1	805	22
1	805	24
1	805	25
1	806	1
1	806	2
1	806	3
1	806	5
1	806	6
1	806	7
1	806	8
1	806	10
1	806	14
1	806	15
1	806	16
1	806	19
1	806	20
1	806	24
1	806	25
1	807	2
1	807	3
1	807	4
1	807	5
1	807	7
1	807	8
1	807	10
1	807	11
1	807	13
1	807	18
1	807	19
1	807	21
1	807	22
1	807	24
1	807	25
1	808	4
1	808	6
1	808	7
1	808	10
1	808	11
1	808	12
1	808	14
1	808	16
1	808	17
1	808	18
1	808	20
1	808	21
1	808	22
1	808	24
1	808	25
1	809	1
1	809	2
1	809	4
1	809	5
1	809	7
1	809	9
1	809	13
1	809	16
1	809	18
1	809	19
1	809	21
1	809	22
1	809	23
1	809	24
1	809	25
1	810	1
1	810	3
1	810	6
1	810	7
1	810	9
1	810	11
1	810	12
1	810	15
1	810	16
1	810	17
1	810	18
1	810	21
1	810	22
1	810	23
1	810	24
1	811	1
1	811	2
1	811	3
1	811	4
1	811	5
1	811	6
1	811	7
1	811	9
1	811	10
1	811	12
1	811	14
1	811	17
1	811	19
1	811	20
1	811	22
1	812	1
1	812	3
1	812	5
1	812	7
1	812	8
1	812	11
1	812	14
1	812	17
1	812	18
1	812	19
1	812	20
1	812	21
1	812	23
1	812	24
1	812	25
1	813	1
1	813	3
1	813	4
1	813	5
1	813	6
1	813	7
1	813	8
1	813	10
1	813	12
1	813	16
1	813	19
1	813	21
1	813	23
1	813	24
1	813	25
1	814	3
1	814	4
1	814	8
1	814	10
1	814	11
1	814	12
1	814	13
1	814	14
1	814	17
1	814	19
1	814	20
1	814	21
1	814	22
1	814	23
1	814	24
1	815	6
1	815	7
1	815	8
1	815	10
1	815	11
1	815	14
1	815	15
1	815	17
1	815	18
1	815	20
1	815	21
1	815	22
1	815	23
1	815	24
1	815	25
1	816	2
1	816	3
1	816	5
1	816	8
1	816	9
1	816	10
1	816	11
1	816	12
1	816	13
1	816	15
1	816	16
1	816	17
1	816	19
1	816	23
1	816	25
1	817	1
1	817	2
1	817	3
1	817	4
1	817	5
1	817	8
1	817	10
1	817	11
1	817	12
1	817	17
1	817	18
1	817	20
1	817	23
1	817	24
1	817	25
1	818	4
1	818	5
1	818	6
1	818	8
1	818	10
1	818	11
1	818	13
1	818	14
1	818	16
1	818	19
1	818	20
1	818	22
1	818	23
1	818	24
1	818	25
1	819	3
1	819	4
1	819	5
1	819	6
1	819	7
1	819	8
1	819	9
1	819	10
1	819	11
1	819	12
1	819	18
1	819	19
1	819	20
1	819	21
1	819	22
1	820	1
1	820	2
1	820	3
1	820	5
1	820	6
1	820	7
1	820	8
1	820	9
1	820	10
1	820	13
1	820	15
1	820	16
1	820	22
1	820	23
1	820	24
1	821	3
1	821	4
1	821	5
1	821	7
1	821	9
1	821	10
1	821	11
1	821	12
1	821	14
1	821	16
1	821	17
1	821	21
1	821	23
1	821	24
1	821	25
1	822	2
1	822	3
1	822	5
1	822	11
1	822	12
1	822	14
1	822	15
1	822	16
1	822	17
1	822	18
1	822	19
1	822	21
1	822	22
1	822	23
1	822	24
1	823	1
1	823	2
1	823	4
1	823	5
1	823	9
1	823	11
1	823	12
1	823	13
1	823	14
1	823	16
1	823	19
1	823	20
1	823	22
1	823	24
1	823	25
1	824	2
1	824	3
1	824	4
1	824	7
1	824	11
1	824	12
1	824	13
1	824	14
1	824	15
1	824	19
1	824	20
1	824	21
1	824	22
1	824	24
1	824	25
1	825	1
1	825	6
1	825	7
1	825	8
1	825	9
1	825	10
1	825	11
1	825	13
1	825	14
1	825	15
1	825	17
1	825	19
1	825	22
1	825	23
1	825	25
1	826	3
1	826	5
1	826	6
1	826	12
1	826	13
1	826	14
1	826	15
1	826	16
1	826	17
1	826	18
1	826	19
1	826	20
1	826	21
1	826	23
1	826	24
1	827	1
1	827	2
1	827	4
1	827	5
1	827	7
1	827	9
1	827	10
1	827	12
1	827	13
1	827	14
1	827	16
1	827	17
1	827	21
1	827	22
1	827	24
1	828	1
1	828	6
1	828	7
1	828	8
1	828	9
1	828	12
1	828	14
1	828	15
1	828	17
1	828	19
1	828	20
1	828	22
1	828	23
1	828	24
1	828	25
1	829	2
1	829	5
1	829	7
1	829	8
1	829	9
1	829	11
1	829	13
1	829	14
1	829	16
1	829	17
1	829	18
1	829	22
1	829	23
1	829	24
1	829	25
1	830	1
1	830	4
1	830	6
1	830	9
1	830	10
1	830	11
1	830	12
1	830	13
1	830	14
1	830	16
1	830	17
1	830	19
1	830	21
1	830	23
1	830	24
1	831	1
1	831	2
1	831	3
1	831	5
1	831	9
1	831	10
1	831	11
1	831	12
1	831	14
1	831	16
1	831	17
1	831	18
1	831	20
1	831	21
1	831	22
1	832	2
1	832	5
1	832	6
1	832	7
1	832	8
1	832	10
1	832	11
1	832	12
1	832	15
1	832	16
1	832	19
1	832	22
1	832	23
1	832	24
1	832	25
1	833	2
1	833	5
1	833	6
1	833	7
1	833	10
1	833	11
1	833	12
1	833	13
1	833	16
1	833	17
1	833	18
1	833	19
1	833	20
1	833	22
1	833	25
1	834	2
1	834	4
1	834	7
1	834	8
1	834	9
1	834	10
1	834	11
1	834	14
1	834	16
1	834	18
1	834	19
1	834	20
1	834	21
1	834	22
1	834	23
1	835	1
1	835	2
1	835	4
1	835	6
1	835	8
1	835	12
1	835	14
1	835	15
1	835	16
1	835	17
1	835	18
1	835	19
1	835	21
1	835	24
1	835	25
1	836	2
1	836	4
1	836	7
1	836	8
1	836	9
1	836	10
1	836	12
1	836	14
1	836	15
1	836	16
1	836	18
1	836	20
1	836	21
1	836	22
1	836	25
1	837	1
1	837	3
1	837	7
1	837	8
1	837	10
1	837	11
1	837	12
1	837	13
1	837	14
1	837	15
1	837	16
1	837	18
1	837	20
1	837	22
1	837	24
1	838	2
1	838	4
1	838	5
1	838	7
1	838	9
1	838	10
1	838	11
1	838	14
1	838	15
1	838	16
1	838	18
1	838	20
1	838	21
1	838	23
1	838	24
1	839	2
1	839	3
1	839	4
1	839	6
1	839	7
1	839	8
1	839	13
1	839	14
1	839	16
1	839	17
1	839	19
1	839	21
1	839	22
1	839	24
1	839	25
1	840	2
1	840	4
1	840	6
1	840	9
1	840	11
1	840	12
1	840	13
1	840	17
1	840	18
1	840	19
1	840	20
1	840	21
1	840	22
1	840	23
1	840	25
1	841	1
1	841	3
1	841	5
1	841	6
1	841	8
1	841	10
1	841	12
1	841	13
1	841	14
1	841	15
1	841	16
1	841	17
1	841	20
1	841	21
1	841	24
1	842	3
1	842	4
1	842	5
1	842	7
1	842	10
1	842	11
1	842	13
1	842	14
1	842	15
1	842	18
1	842	19
1	842	20
1	842	21
1	842	22
1	842	24
1	843	3
1	843	4
1	843	7
1	843	8
1	843	11
1	843	12
1	843	13
1	843	15
1	843	16
1	843	17
1	843	19
1	843	20
1	843	21
1	843	22
1	843	24
1	844	1
1	844	3
1	844	5
1	844	7
1	844	8
1	844	9
1	844	10
1	844	12
1	844	15
1	844	16
1	844	17
1	844	19
1	844	22
1	844	24
1	844	25
1	845	2
1	845	4
1	845	6
1	845	7
1	845	11
1	845	12
1	845	14
1	845	16
1	845	18
1	845	19
1	845	21
1	845	22
1	845	23
1	845	24
1	845	25
1	846	1
1	846	4
1	846	6
1	846	9
1	846	10
1	846	11
1	846	13
1	846	14
1	846	15
1	846	19
1	846	20
1	846	21
1	846	23
1	846	24
1	846	25
1	847	1
1	847	3
1	847	5
1	847	6
1	847	7
1	847	9
1	847	10
1	847	11
1	847	13
1	847	14
1	847	17
1	847	18
1	847	20
1	847	21
1	847	25
1	848	2
1	848	3
1	848	5
1	848	8
1	848	9
1	848	13
1	848	14
1	848	16
1	848	17
1	848	18
1	848	19
1	848	21
1	848	23
1	848	24
1	848	25
1	849	1
1	849	4
1	849	5
1	849	10
1	849	12
1	849	13
1	849	14
1	849	15
1	849	16
1	849	17
1	849	18
1	849	20
1	849	23
1	849	24
1	849	25
1	850	2
1	850	3
1	850	5
1	850	7
1	850	8
1	850	10
1	850	13
1	850	14
1	850	18
1	850	19
1	850	20
1	850	21
1	850	22
1	850	23
1	850	24
1	851	1
1	851	4
1	851	5
1	851	6
1	851	7
1	851	10
1	851	13
1	851	14
1	851	15
1	851	17
1	851	18
1	851	19
1	851	20
1	851	22
1	851	24
1	852	1
1	852	2
1	852	3
1	852	4
1	852	5
1	852	8
1	852	11
1	852	12
1	852	16
1	852	18
1	852	20
1	852	21
1	852	23
1	852	24
1	852	25
1	853	2
1	853	3
1	853	5
1	853	6
1	853	8
1	853	9
1	853	11
1	853	12
1	853	17
1	853	18
1	853	19
1	853	20
1	853	21
1	853	22
1	853	23
1	854	1
1	854	2
1	854	3
1	854	5
1	854	8
1	854	9
1	854	10
1	854	13
1	854	14
1	854	15
1	854	17
1	854	18
1	854	20
1	854	21
1	854	22
1	855	1
1	855	3
1	855	4
1	855	8
1	855	9
1	855	10
1	855	11
1	855	13
1	855	14
1	855	15
1	855	17
1	855	18
1	855	23
1	855	24
1	855	25
1	856	2
1	856	3
1	856	7
1	856	8
1	856	9
1	856	11
1	856	12
1	856	13
1	856	15
1	856	16
1	856	19
1	856	20
1	856	22
1	856	23
1	856	25
1	857	1
1	857	3
1	857	4
1	857	6
1	857	8
1	857	11
1	857	13
1	857	14
1	857	15
1	857	16
1	857	18
1	857	19
1	857	20
1	857	21
1	857	24
1	858	1
1	858	3
1	858	4
1	858	5
1	858	6
1	858	8
1	858	9
1	858	11
1	858	12
1	858	17
1	858	19
1	858	20
1	858	22
1	858	23
1	858	25
1	859	1
1	859	2
1	859	3
1	859	4
1	859	5
1	859	6
1	859	9
1	859	10
1	859	11
1	859	13
1	859	14
1	859	17
1	859	18
1	859	19
1	859	20
1	860	3
1	860	4
1	860	5
1	860	6
1	860	7
1	860	9
1	860	10
1	860	13
1	860	14
1	860	15
1	860	16
1	860	19
1	860	22
1	860	24
1	860	25
1	861	1
1	861	2
1	861	3
1	861	4
1	861	6
1	861	7
1	861	9
1	861	10
1	861	11
1	861	14
1	861	15
1	861	17
1	861	19
1	861	22
1	861	23
1	862	1
1	862	2
1	862	3
1	862	4
1	862	5
1	862	10
1	862	13
1	862	14
1	862	15
1	862	17
1	862	18
1	862	19
1	862	20
1	862	23
1	862	24
1	863	1
1	863	3
1	863	4
1	863	7
1	863	8
1	863	13
1	863	15
1	863	16
1	863	17
1	863	18
1	863	19
1	863	22
1	863	23
1	863	24
1	863	25
1	864	3
1	864	6
1	864	8
1	864	10
1	864	12
1	864	13
1	864	15
1	864	16
1	864	17
1	864	18
1	864	19
1	864	21
1	864	22
1	864	23
1	864	24
1	865	1
1	865	3
1	865	4
1	865	5
1	865	6
1	865	7
1	865	10
1	865	13
1	865	18
1	865	19
1	865	20
1	865	21
1	865	22
1	865	23
1	865	25
1	866	1
1	866	2
1	866	3
1	866	5
1	866	7
1	866	8
1	866	9
1	866	10
1	866	11
1	866	13
1	866	14
1	866	18
1	866	20
1	866	23
1	866	24
1	867	2
1	867	3
1	867	4
1	867	5
1	867	6
1	867	7
1	867	8
1	867	10
1	867	12
1	867	13
1	867	14
1	867	15
1	867	21
1	867	22
1	867	25
1	868	1
1	868	2
1	868	3
1	868	8
1	868	9
1	868	10
1	868	12
1	868	13
1	868	14
1	868	16
1	868	17
1	868	19
1	868	21
1	868	22
1	868	24
1	869	1
1	869	3
1	869	6
1	869	9
1	869	10
1	869	11
1	869	12
1	869	14
1	869	18
1	869	20
1	869	21
1	869	22
1	869	23
1	869	24
1	869	25
1	870	1
1	870	2
1	870	4
1	870	5
1	870	6
1	870	7
1	870	8
1	870	10
1	870	12
1	870	13
1	870	14
1	870	16
1	870	17
1	870	18
1	870	23
1	871	2
1	871	4
1	871	6
1	871	8
1	871	9
1	871	10
1	871	12
1	871	13
1	871	14
1	871	15
1	871	17
1	871	19
1	871	22
1	871	23
1	871	24
1	872	1
1	872	2
1	872	4
1	872	5
1	872	6
1	872	7
1	872	9
1	872	10
1	872	12
1	872	13
1	872	14
1	872	17
1	872	18
1	872	22
1	872	23
1	873	2
1	873	3
1	873	6
1	873	7
1	873	8
1	873	9
1	873	11
1	873	12
1	873	13
1	873	14
1	873	15
1	873	17
1	873	18
1	873	22
1	873	25
1	874	1
1	874	2
1	874	4
1	874	5
1	874	6
1	874	7
1	874	8
1	874	9
1	874	10
1	874	16
1	874	19
1	874	20
1	874	21
1	874	23
1	874	25
1	875	2
1	875	4
1	875	6
1	875	8
1	875	9
1	875	10
1	875	12
1	875	13
1	875	15
1	875	18
1	875	21
1	875	22
1	875	23
1	875	24
1	875	25
1	876	3
1	876	5
1	876	6
1	876	7
1	876	9
1	876	12
1	876	13
1	876	14
1	876	16
1	876	18
1	876	20
1	876	21
1	876	23
1	876	24
1	876	25
1	877	3
1	877	7
1	877	8
1	877	9
1	877	10
1	877	11
1	877	13
1	877	14
1	877	15
1	877	16
1	877	18
1	877	19
1	877	21
1	877	23
1	877	25
1	878	1
1	878	2
1	878	3
1	878	5
1	878	6
1	878	7
1	878	10
1	878	12
1	878	13
1	878	14
1	878	16
1	878	19
1	878	22
1	878	23
1	878	25
1	879	2
1	879	3
1	879	4
1	879	7
1	879	9
1	879	10
1	879	12
1	879	13
1	879	15
1	879	16
1	879	18
1	879	21
1	879	22
1	879	24
1	879	25
1	880	2
1	880	5
1	880	6
1	880	7
1	880	8
1	880	10
1	880	14
1	880	16
1	880	18
1	880	19
1	880	21
1	880	22
1	880	23
1	880	24
1	880	25
1	881	1
1	881	3
1	881	4
1	881	5
1	881	6
1	881	7
1	881	8
1	881	9
1	881	15
1	881	16
1	881	19
1	881	20
1	881	21
1	881	22
1	881	23
1	882	1
1	882	2
1	882	7
1	882	8
1	882	10
1	882	11
1	882	12
1	882	13
1	882	14
1	882	17
1	882	18
1	882	19
1	882	22
1	882	24
1	882	25
1	883	3
1	883	5
1	883	6
1	883	7
1	883	8
1	883	9
1	883	10
1	883	12
1	883	16
1	883	17
1	883	18
1	883	19
1	883	21
1	883	22
1	883	25
1	884	1
1	884	4
1	884	7
1	884	8
1	884	9
1	884	10
1	884	12
1	884	13
1	884	15
1	884	17
1	884	18
1	884	19
1	884	20
1	884	21
1	884	25
1	885	2
1	885	5
1	885	7
1	885	8
1	885	9
1	885	11
1	885	12
1	885	15
1	885	16
1	885	17
1	885	18
1	885	19
1	885	22
1	885	23
1	885	24
1	886	1
1	886	3
1	886	4
1	886	7
1	886	8
1	886	10
1	886	11
1	886	12
1	886	13
1	886	15
1	886	16
1	886	17
1	886	20
1	886	21
1	886	23
1	887	1
1	887	6
1	887	8
1	887	10
1	887	11
1	887	12
1	887	15
1	887	17
1	887	18
1	887	19
1	887	20
1	887	21
1	887	23
1	887	24
1	887	25
1	888	1
1	888	3
1	888	6
1	888	11
1	888	12
1	888	13
1	888	14
1	888	16
1	888	17
1	888	18
1	888	19
1	888	20
1	888	21
1	888	22
1	888	24
1	889	2
1	889	4
1	889	5
1	889	6
1	889	7
1	889	9
1	889	11
1	889	12
1	889	13
1	889	16
1	889	18
1	889	19
1	889	21
1	889	22
1	889	25
1	890	1
1	890	2
1	890	3
1	890	4
1	890	5
1	890	6
1	890	7
1	890	8
1	890	11
1	890	16
1	890	17
1	890	18
1	890	19
1	890	23
1	890	24
1	891	1
1	891	5
1	891	6
1	891	7
1	891	8
1	891	12
1	891	14
1	891	15
1	891	16
1	891	17
1	891	19
1	891	21
1	891	23
1	891	24
1	891	25
1	892	1
1	892	2
1	892	3
1	892	5
1	892	6
1	892	10
1	892	13
1	892	14
1	892	16
1	892	17
1	892	19
1	892	20
1	892	21
1	892	22
1	892	24
1	893	1
1	893	2
1	893	3
1	893	4
1	893	5
1	893	6
1	893	8
1	893	9
1	893	11
1	893	15
1	893	16
1	893	20
1	893	22
1	893	23
1	893	24
1	894	1
1	894	2
1	894	5
1	894	6
1	894	9
1	894	12
1	894	13
1	894	14
1	894	15
1	894	18
1	894	19
1	894	21
1	894	22
1	894	24
1	894	25
1	895	2
1	895	3
1	895	4
1	895	5
1	895	6
1	895	8
1	895	11
1	895	12
1	895	13
1	895	16
1	895	17
1	895	18
1	895	19
1	895	21
1	895	25
1	896	1
1	896	2
1	896	3
1	896	4
1	896	6
1	896	7
1	896	8
1	896	12
1	896	13
1	896	15
1	896	17
1	896	18
1	896	19
1	896	20
1	896	23
1	897	1
1	897	2
1	897	5
1	897	7
1	897	8
1	897	9
1	897	10
1	897	11
1	897	13
1	897	14
1	897	16
1	897	17
1	897	18
1	897	21
1	897	23
1	898	1
1	898	4
1	898	6
1	898	8
1	898	9
1	898	10
1	898	11
1	898	12
1	898	13
1	898	14
1	898	18
1	898	20
1	898	21
1	898	24
1	898	25
1	899	1
1	899	4
1	899	7
1	899	9
1	899	10
1	899	12
1	899	14
1	899	15
1	899	16
1	899	17
1	899	18
1	899	20
1	899	21
1	899	23
1	899	25
1	900	1
1	900	2
1	900	6
1	900	7
1	900	8
1	900	10
1	900	11
1	900	12
1	900	13
1	900	15
1	900	18
1	900	20
1	900	22
1	900	24
1	900	25
1	901	1
1	901	2
1	901	4
1	901	6
1	901	7
1	901	10
1	901	12
1	901	13
1	901	14
1	901	16
1	901	18
1	901	22
1	901	23
1	901	24
1	901	25
1	902	1
1	902	2
1	902	3
1	902	4
1	902	5
1	902	6
1	902	8
1	902	9
1	902	11
1	902	17
1	902	20
1	902	21
1	902	23
1	902	24
1	902	25
1	903	1
1	903	2
1	903	3
1	903	4
1	903	5
1	903	6
1	903	8
1	903	10
1	903	11
1	903	13
1	903	15
1	903	16
1	903	18
1	903	20
1	903	22
1	904	1
1	904	5
1	904	6
1	904	7
1	904	9
1	904	10
1	904	12
1	904	13
1	904	16
1	904	17
1	904	18
1	904	19
1	904	20
1	904	22
1	904	24
1	905	1
1	905	4
1	905	6
1	905	8
1	905	10
1	905	11
1	905	12
1	905	13
1	905	14
1	905	16
1	905	17
1	905	20
1	905	21
1	905	22
1	905	23
1	906	1
1	906	2
1	906	3
1	906	5
1	906	6
1	906	7
1	906	8
1	906	9
1	906	10
1	906	12
1	906	17
1	906	18
1	906	21
1	906	22
1	906	24
1	907	2
1	907	3
1	907	4
1	907	5
1	907	7
1	907	8
1	907	10
1	907	13
1	907	14
1	907	15
1	907	16
1	907	20
1	907	21
1	907	22
1	907	23
1	908	1
1	908	2
1	908	4
1	908	6
1	908	7
1	908	9
1	908	10
1	908	12
1	908	13
1	908	15
1	908	17
1	908	18
1	908	23
1	908	24
1	908	25
1	909	1
1	909	2
1	909	3
1	909	5
1	909	6
1	909	7
1	909	8
1	909	10
1	909	11
1	909	12
1	909	13
1	909	18
1	909	20
1	909	21
1	909	22
1	910	3
1	910	4
1	910	5
1	910	6
1	910	8
1	910	9
1	910	11
1	910	13
1	910	16
1	910	17
1	910	18
1	910	19
1	910	20
1	910	24
1	910	25
1	911	1
1	911	2
1	911	3
1	911	5
1	911	6
1	911	8
1	911	11
1	911	13
1	911	15
1	911	17
1	911	21
1	911	22
1	911	23
1	911	24
1	911	25
1	912	2
1	912	3
1	912	4
1	912	7
1	912	10
1	912	14
1	912	15
1	912	16
1	912	17
1	912	18
1	912	19
1	912	20
1	912	21
1	912	22
1	912	23
1	913	3
1	913	4
1	913	5
1	913	6
1	913	10
1	913	12
1	913	13
1	913	15
1	913	17
1	913	18
1	913	19
1	913	20
1	913	22
1	913	24
1	913	25
1	914	1
1	914	3
1	914	4
1	914	5
1	914	6
1	914	10
1	914	11
1	914	12
1	914	15
1	914	17
1	914	18
1	914	20
1	914	22
1	914	23
1	914	24
1	915	1
1	915	2
1	915	4
1	915	5
1	915	6
1	915	8
1	915	10
1	915	11
1	915	13
1	915	18
1	915	20
1	915	22
1	915	23
1	915	24
1	915	25
1	916	1
1	916	2
1	916	3
1	916	4
1	916	5
1	916	6
1	916	7
1	916	11
1	916	13
1	916	14
1	916	17
1	916	18
1	916	19
1	916	23
1	916	24
1	917	1
1	917	2
1	917	3
1	917	4
1	917	5
1	917	6
1	917	11
1	917	13
1	917	14
1	917	17
1	917	19
1	917	20
1	917	21
1	917	22
1	917	24
1	918	1
1	918	2
1	918	3
1	918	4
1	918	6
1	918	8
1	918	9
1	918	13
1	918	14
1	918	15
1	918	16
1	918	17
1	918	21
1	918	22
1	918	23
1	919	1
1	919	2
1	919	3
1	919	4
1	919	5
1	919	7
1	919	9
1	919	10
1	919	11
1	919	13
1	919	14
1	919	17
1	919	19
1	919	21
1	919	22
1	920	1
1	920	2
1	920	3
1	920	4
1	920	5
1	920	6
1	920	10
1	920	12
1	920	13
1	920	15
1	920	16
1	920	19
1	920	20
1	920	22
1	920	23
1	921	1
1	921	2
1	921	3
1	921	4
1	921	7
1	921	9
1	921	12
1	921	15
1	921	16
1	921	17
1	921	18
1	921	19
1	921	21
1	921	24
1	921	25
1	922	2
1	922	4
1	922	5
1	922	6
1	922	8
1	922	9
1	922	12
1	922	15
1	922	16
1	922	17
1	922	20
1	922	21
1	922	22
1	922	23
1	922	24
1	923	1
1	923	3
1	923	4
1	923	5
1	923	6
1	923	7
1	923	10
1	923	12
1	923	14
1	923	15
1	923	19
1	923	20
1	923	22
1	923	24
1	923	25
1	924	1
1	924	2
1	924	6
1	924	7
1	924	8
1	924	9
1	924	10
1	924	12
1	924	14
1	924	16
1	924	17
1	924	18
1	924	19
1	924	20
1	924	24
1	925	1
1	925	3
1	925	4
1	925	6
1	925	7
1	925	9
1	925	12
1	925	13
1	925	14
1	925	15
1	925	16
1	925	22
1	925	23
1	925	24
1	925	25
1	926	1
1	926	5
1	926	6
1	926	7
1	926	8
1	926	9
1	926	10
1	926	11
1	926	12
1	926	13
1	926	14
1	926	15
1	926	19
1	926	21
1	926	24
1	927	2
1	927	3
1	927	5
1	927	6
1	927	9
1	927	11
1	927	13
1	927	14
1	927	16
1	927	17
1	927	20
1	927	21
1	927	22
1	927	23
1	927	25
1	928	1
1	928	4
1	928	6
1	928	8
1	928	9
1	928	10
1	928	11
1	928	12
1	928	14
1	928	15
1	928	17
1	928	19
1	928	23
1	928	24
1	928	25
1	929	1
1	929	2
1	929	4
1	929	5
1	929	7
1	929	8
1	929	9
1	929	10
1	929	11
1	929	14
1	929	18
1	929	20
1	929	21
1	929	23
1	929	25
1	930	2
1	930	3
1	930	5
1	930	6
1	930	9
1	930	11
1	930	12
1	930	14
1	930	15
1	930	16
1	930	20
1	930	22
1	930	23
1	930	24
1	930	25
1	931	2
1	931	3
1	931	5
1	931	6
1	931	8
1	931	10
1	931	11
1	931	12
1	931	14
1	931	16
1	931	19
1	931	20
1	931	22
1	931	24
1	931	25
1	932	1
1	932	4
1	932	5
1	932	8
1	932	12
1	932	13
1	932	14
1	932	15
1	932	16
1	932	18
1	932	20
1	932	21
1	932	22
1	932	23
1	932	25
1	933	2
1	933	3
1	933	4
1	933	5
1	933	6
1	933	7
1	933	10
1	933	11
1	933	14
1	933	15
1	933	16
1	933	17
1	933	19
1	933	23
1	933	24
1	934	2
1	934	3
1	934	4
1	934	8
1	934	9
1	934	10
1	934	11
1	934	14
1	934	19
1	934	20
1	934	21
1	934	22
1	934	23
1	934	24
1	934	25
1	935	1
1	935	2
1	935	3
1	935	4
1	935	5
1	935	6
1	935	7
1	935	9
1	935	10
1	935	12
1	935	14
1	935	18
1	935	19
1	935	22
1	935	23
1	936	1
1	936	2
1	936	3
1	936	4
1	936	6
1	936	7
1	936	8
1	936	13
1	936	15
1	936	17
1	936	18
1	936	19
1	936	20
1	936	23
1	936	25
1	937	1
1	937	2
1	937	6
1	937	9
1	937	10
1	937	11
1	937	12
1	937	13
1	937	14
1	937	16
1	937	19
1	937	20
1	937	23
1	937	24
1	937	25
1	938	2
1	938	3
1	938	4
1	938	6
1	938	7
1	938	10
1	938	11
1	938	13
1	938	15
1	938	16
1	938	17
1	938	18
1	938	19
1	938	20
1	938	25
1	939	1
1	939	4
1	939	5
1	939	6
1	939	7
1	939	9
1	939	10
1	939	11
1	939	15
1	939	16
1	939	18
1	939	19
1	939	20
1	939	21
1	939	25
1	940	2
1	940	3
1	940	4
1	940	6
1	940	7
1	940	9
1	940	13
1	940	14
1	940	16
1	940	17
1	940	18
1	940	19
1	940	20
1	940	24
1	940	25
1	941	1
1	941	2
1	941	3
1	941	4
1	941	5
1	941	7
1	941	8
1	941	9
1	941	10
1	941	11
1	941	15
1	941	16
1	941	18
1	941	23
1	941	25
1	942	1
1	942	3
1	942	4
1	942	5
1	942	6
1	942	7
1	942	11
1	942	12
1	942	13
1	942	18
1	942	19
1	942	20
1	942	21
1	942	22
1	942	24
1	943	3
1	943	4
1	943	5
1	943	6
1	943	9
1	943	10
1	943	12
1	943	13
1	943	14
1	943	15
1	943	17
1	943	18
1	943	21
1	943	22
1	943	23
1	944	1
1	944	8
1	944	9
1	944	10
1	944	11
1	944	12
1	944	13
1	944	14
1	944	16
1	944	17
1	944	18
1	944	19
1	944	21
1	944	24
1	944	25
1	945	2
1	945	3
1	945	4
1	945	5
1	945	6
1	945	9
1	945	11
1	945	13
1	945	18
1	945	19
1	945	20
1	945	21
1	945	23
1	945	24
1	945	25
1	946	1
1	946	7
1	946	8
1	946	9
1	946	10
1	946	14
1	946	16
1	946	17
1	946	18
1	946	19
1	946	20
1	946	21
1	946	22
1	946	24
1	946	25
1	947	1
1	947	2
1	947	3
1	947	5
1	947	7
1	947	9
1	947	10
1	947	11
1	947	12
1	947	15
1	947	16
1	947	18
1	947	20
1	947	22
1	947	24
1	948	1
1	948	2
1	948	5
1	948	6
1	948	8
1	948	9
1	948	11
1	948	13
1	948	16
1	948	17
1	948	18
1	948	19
1	948	21
1	948	22
1	948	24
1	949	1
1	949	6
1	949	7
1	949	8
1	949	9
1	949	10
1	949	11
1	949	12
1	949	13
1	949	14
1	949	15
1	949	16
1	949	17
1	949	21
1	949	23
1	950	2
1	950	4
1	950	5
1	950	7
1	950	8
1	950	9
1	950	12
1	950	13
1	950	14
1	950	17
1	950	18
1	950	19
1	950	20
1	950	21
1	950	25
1	951	3
1	951	7
1	951	8
1	951	9
1	951	10
1	951	13
1	951	14
1	951	15
1	951	17
1	951	19
1	951	20
1	951	21
1	951	22
1	951	23
1	951	25
1	952	1
1	952	3
1	952	4
1	952	6
1	952	8
1	952	11
1	952	12
1	952	14
1	952	17
1	952	18
1	952	19
1	952	21
1	952	22
1	952	23
1	952	25
1	953	1
1	953	2
1	953	5
1	953	6
1	953	7
1	953	9
1	953	10
1	953	12
1	953	13
1	953	14
1	953	15
1	953	16
1	953	18
1	953	21
1	953	24
1	954	3
1	954	5
1	954	6
1	954	8
1	954	10
1	954	11
1	954	12
1	954	13
1	954	14
1	954	16
1	954	18
1	954	20
1	954	23
1	954	24
1	954	25
1	955	1
1	955	2
1	955	4
1	955	5
1	955	7
1	955	9
1	955	10
1	955	11
1	955	12
1	955	13
1	955	14
1	955	16
1	955	18
1	955	21
1	955	24
1	956	2
1	956	3
1	956	4
1	956	5
1	956	6
1	956	8
1	956	11
1	956	12
1	956	13
1	956	16
1	956	17
1	956	18
1	956	19
1	956	21
1	956	22
1	957	1
1	957	3
1	957	4
1	957	5
1	957	6
1	957	7
1	957	8
1	957	13
1	957	15
1	957	16
1	957	21
1	957	22
1	957	23
1	957	24
1	957	25
1	958	1
1	958	4
1	958	5
1	958	6
1	958	9
1	958	12
1	958	13
1	958	14
1	958	16
1	958	17
1	958	19
1	958	20
1	958	21
1	958	22
1	958	24
1	959	2
1	959	5
1	959	6
1	959	9
1	959	11
1	959	12
1	959	14
1	959	16
1	959	19
1	959	20
1	959	21
1	959	22
1	959	23
1	959	24
1	959	25
1	960	1
1	960	2
1	960	3
1	960	4
1	960	6
1	960	7
1	960	10
1	960	12
1	960	14
1	960	16
1	960	17
1	960	18
1	960	20
1	960	21
1	960	24
1	961	1
1	961	2
1	961	3
1	961	4
1	961	5
1	961	7
1	961	9
1	961	11
1	961	12
1	961	15
1	961	18
1	961	20
1	961	21
1	961	22
1	961	25
1	962	1
1	962	4
1	962	6
1	962	8
1	962	9
1	962	11
1	962	13
1	962	14
1	962	15
1	962	17
1	962	20
1	962	21
1	962	22
1	962	23
1	962	25
1	963	3
1	963	4
1	963	6
1	963	7
1	963	9
1	963	10
1	963	11
1	963	14
1	963	15
1	963	16
1	963	17
1	963	18
1	963	19
1	963	23
1	963	24
1	964	1
1	964	2
1	964	3
1	964	4
1	964	7
1	964	9
1	964	10
1	964	11
1	964	15
1	964	17
1	964	18
1	964	19
1	964	20
1	964	21
1	964	23
1	965	3
1	965	4
1	965	8
1	965	9
1	965	10
1	965	11
1	965	13
1	965	14
1	965	15
1	965	16
1	965	18
1	965	19
1	965	21
1	965	22
1	965	24
1	966	2
1	966	3
1	966	4
1	966	5
1	966	6
1	966	7
1	966	8
1	966	10
1	966	11
1	966	12
1	966	17
1	966	19
1	966	21
1	966	22
1	966	25
1	967	2
1	967	3
1	967	4
1	967	6
1	967	8
1	967	9
1	967	10
1	967	11
1	967	16
1	967	17
1	967	20
1	967	21
1	967	22
1	967	23
1	967	25
1	968	2
1	968	3
1	968	4
1	968	5
1	968	7
1	968	9
1	968	11
1	968	13
1	968	14
1	968	16
1	968	18
1	968	19
1	968	20
1	968	21
1	968	25
1	969	1
1	969	3
1	969	4
1	969	5
1	969	9
1	969	10
1	969	11
1	969	12
1	969	16
1	969	17
1	969	18
1	969	19
1	969	20
1	969	22
1	969	24
1	970	1
1	970	3
1	970	6
1	970	8
1	970	9
1	970	10
1	970	12
1	970	15
1	970	17
1	970	18
1	970	19
1	970	20
1	970	21
1	970	23
1	970	24
1	971	3
1	971	4
1	971	5
1	971	6
1	971	7
1	971	9
1	971	10
1	971	11
1	971	18
1	971	20
1	971	21
1	971	22
1	971	23
1	971	24
1	971	25
1	972	1
1	972	3
1	972	6
1	972	8
1	972	11
1	972	13
1	972	14
1	972	15
1	972	16
1	972	20
1	972	21
1	972	22
1	972	23
1	972	24
1	972	25
1	973	1
1	973	2
1	973	3
1	973	5
1	973	6
1	973	8
1	973	11
1	973	14
1	973	15
1	973	18
1	973	20
1	973	21
1	973	22
1	973	24
1	973	25
1	974	1
1	974	4
1	974	6
1	974	7
1	974	8
1	974	9
1	974	10
1	974	12
1	974	14
1	974	15
1	974	17
1	974	19
1	974	21
1	974	22
1	974	24
1	975	1
1	975	2
1	975	4
1	975	6
1	975	7
1	975	10
1	975	11
1	975	12
1	975	13
1	975	14
1	975	16
1	975	17
1	975	19
1	975	20
1	975	24
1	976	1
1	976	2
1	976	3
1	976	4
1	976	6
1	976	7
1	976	10
1	976	11
1	976	13
1	976	14
1	976	19
1	976	21
1	976	23
1	976	24
1	976	25
1	977	1
1	977	2
1	977	6
1	977	7
1	977	8
1	977	10
1	977	11
1	977	13
1	977	14
1	977	17
1	977	18
1	977	20
1	977	22
1	977	23
1	977	24
1	978	3
1	978	4
1	978	5
1	978	6
1	978	7
1	978	8
1	978	9
1	978	11
1	978	12
1	978	13
1	978	14
1	978	15
1	978	16
1	978	18
1	978	25
1	979	2
1	979	5
1	979	6
1	979	7
1	979	8
1	979	9
1	979	10
1	979	14
1	979	16
1	979	19
1	979	21
1	979	22
1	979	23
1	979	24
1	979	25
1	980	1
1	980	2
1	980	6
1	980	7
1	980	8
1	980	9
1	980	10
1	980	11
1	980	12
1	980	13
1	980	17
1	980	20
1	980	21
1	980	22
1	980	24
1	981	1
1	981	2
1	981	3
1	981	4
1	981	6
1	981	8
1	981	9
1	981	12
1	981	16
1	981	18
1	981	19
1	981	21
1	981	22
1	981	24
1	981	25
1	982	1
1	982	3
1	982	4
1	982	5
1	982	6
1	982	7
1	982	9
1	982	13
1	982	14
1	982	17
1	982	18
1	982	20
1	982	21
1	982	23
1	982	24
1	983	2
1	983	4
1	983	5
1	983	6
1	983	7
1	983	8
1	983	10
1	983	11
1	983	14
1	983	15
1	983	16
1	983	18
1	983	19
1	983	21
1	983	25
1	984	2
1	984	4
1	984	8
1	984	9
1	984	10
1	984	11
1	984	12
1	984	13
1	984	15
1	984	20
1	984	21
1	984	22
1	984	23
1	984	24
1	984	25
1	985	3
1	985	4
1	985	6
1	985	7
1	985	9
1	985	12
1	985	13
1	985	14
1	985	17
1	985	18
1	985	21
1	985	22
1	985	23
1	985	24
1	985	25
1	986	1
1	986	2
1	986	5
1	986	7
1	986	11
1	986	13
1	986	14
1	986	15
1	986	16
1	986	18
1	986	20
1	986	21
1	986	22
1	986	23
1	986	24
1	987	2
1	987	4
1	987	5
1	987	6
1	987	7
1	987	9
1	987	11
1	987	12
1	987	13
1	987	15
1	987	18
1	987	19
1	987	20
1	987	22
1	987	23
1	988	1
1	988	3
1	988	5
1	988	7
1	988	9
1	988	11
1	988	12
1	988	13
1	988	15
1	988	16
1	988	17
1	988	19
1	988	20
1	988	24
1	988	25
1	989	3
1	989	4
1	989	6
1	989	8
1	989	9
1	989	10
1	989	13
1	989	14
1	989	15
1	989	17
1	989	18
1	989	19
1	989	22
1	989	23
1	989	24
1	990	1
1	990	5
1	990	6
1	990	7
1	990	8
1	990	10
1	990	11
1	990	12
1	990	13
1	990	15
1	990	16
1	990	19
1	990	20
1	990	22
1	990	24
1	991	1
1	991	2
1	991	5
1	991	6
1	991	7
1	991	9
1	991	12
1	991	14
1	991	15
1	991	17
1	991	18
1	991	21
1	991	22
1	991	24
1	991	25
1	992	1
1	992	3
1	992	4
1	992	5
1	992	7
1	992	8
1	992	9
1	992	10
1	992	11
1	992	13
1	992	15
1	992	17
1	992	19
1	992	20
1	992	24
1	993	2
1	993	4
1	993	5
1	993	7
1	993	9
1	993	10
1	993	12
1	993	14
1	993	17
1	993	20
1	993	21
1	993	22
1	993	23
1	993	24
1	993	25
1	994	3
1	994	5
1	994	7
1	994	8
1	994	9
1	994	11
1	994	12
1	994	13
1	994	14
1	994	15
1	994	16
1	994	18
1	994	22
1	994	23
1	994	25
1	995	1
1	995	2
1	995	3
1	995	4
1	995	7
1	995	8
1	995	9
1	995	12
1	995	13
1	995	14
1	995	17
1	995	20
1	995	22
1	995	23
1	995	24
1	996	2
1	996	3
1	996	4
1	996	6
1	996	7
1	996	9
1	996	13
1	996	16
1	996	17
1	996	18
1	996	20
1	996	21
1	996	23
1	996	24
1	996	25
1	997	2
1	997	4
1	997	5
1	997	7
1	997	9
1	997	10
1	997	12
1	997	15
1	997	16
1	997	17
1	997	18
1	997	19
1	997	22
1	997	23
1	997	24
1	998	1
1	998	2
1	998	3
1	998	4
1	998	5
1	998	9
1	998	11
1	998	12
1	998	14
1	998	17
1	998	19
1	998	20
1	998	21
1	998	22
1	998	23
1	999	1
1	999	2
1	999	5
1	999	6
1	999	7
1	999	8
1	999	10
1	999	12
1	999	13
1	999	14
1	999	15
1	999	16
1	999	18
1	999	21
1	999	24
1	1000	2
1	1000	3
1	1000	4
1	1000	8
1	1000	11
1	1000	12
1	1000	13
1	1000	14
1	1000	15
1	1000	16
1	1000	17
1	1000	18
1	1000	19
1	1000	20
1	1000	22
1	1001	5
1	1001	6
1	1001	7
1	1001	8
1	1001	10
1	1001	11
1	1001	12
1	1001	13
1	1001	14
1	1001	17
1	1001	19
1	1001	20
1	1001	21
1	1001	23
1	1001	25
1	1002	3
1	1002	4
1	1002	8
1	1002	10
1	1002	12
1	1002	13
1	1002	14
1	1002	15
1	1002	16
1	1002	17
1	1002	18
1	1002	20
1	1002	21
1	1002	22
1	1002	24
1	1003	1
1	1003	2
1	1003	3
1	1003	6
1	1003	8
1	1003	10
1	1003	12
1	1003	14
1	1003	16
1	1003	17
1	1003	19
1	1003	20
1	1003	21
1	1003	23
1	1003	25
1	1004	1
1	1004	2
1	1004	3
1	1004	6
1	1004	10
1	1004	12
1	1004	14
1	1004	15
1	1004	18
1	1004	19
1	1004	20
1	1004	21
1	1004	22
1	1004	24
1	1004	25
1	1005	1
1	1005	5
1	1005	7
1	1005	9
1	1005	10
1	1005	12
1	1005	14
1	1005	15
1	1005	16
1	1005	18
1	1005	19
1	1005	20
1	1005	21
1	1005	22
1	1005	24
1	1006	1
1	1006	3
1	1006	4
1	1006	5
1	1006	6
1	1006	7
1	1006	9
1	1006	13
1	1006	14
1	1006	15
1	1006	16
1	1006	20
1	1006	22
1	1006	23
1	1006	24
1	1007	1
1	1007	2
1	1007	3
1	1007	6
1	1007	7
1	1007	9
1	1007	10
1	1007	11
1	1007	12
1	1007	18
1	1007	20
1	1007	22
1	1007	23
1	1007	24
1	1007	25
1	1008	1
1	1008	3
1	1008	6
1	1008	7
1	1008	8
1	1008	9
1	1008	10
1	1008	12
1	1008	13
1	1008	16
1	1008	17
1	1008	18
1	1008	19
1	1008	21
1	1008	22
1	1009	2
1	1009	4
1	1009	6
1	1009	9
1	1009	10
1	1009	11
1	1009	12
1	1009	14
1	1009	15
1	1009	17
1	1009	18
1	1009	19
1	1009	20
1	1009	22
1	1009	24
1	1010	1
1	1010	2
1	1010	4
1	1010	6
1	1010	8
1	1010	10
1	1010	11
1	1010	13
1	1010	14
1	1010	15
1	1010	16
1	1010	19
1	1010	21
1	1010	22
1	1010	23
1	1011	1
1	1011	3
1	1011	4
1	1011	5
1	1011	7
1	1011	9
1	1011	10
1	1011	13
1	1011	15
1	1011	17
1	1011	18
1	1011	19
1	1011	23
1	1011	24
1	1011	25
1	1012	1
1	1012	2
1	1012	7
1	1012	9
1	1012	11
1	1012	12
1	1012	14
1	1012	15
1	1012	16
1	1012	17
1	1012	18
1	1012	21
1	1012	22
1	1012	24
1	1012	25
1	1013	1
1	1013	2
1	1013	3
1	1013	4
1	1013	5
1	1013	7
1	1013	10
1	1013	11
1	1013	13
1	1013	17
1	1013	18
1	1013	19
1	1013	20
1	1013	21
1	1013	23
1	1014	1
1	1014	2
1	1014	8
1	1014	9
1	1014	10
1	1014	12
1	1014	13
1	1014	14
1	1014	17
1	1014	18
1	1014	20
1	1014	22
1	1014	23
1	1014	24
1	1014	25
1	1015	1
1	1015	2
1	1015	3
1	1015	5
1	1015	6
1	1015	7
1	1015	8
1	1015	13
1	1015	15
1	1015	16
1	1015	17
1	1015	18
1	1015	20
1	1015	21
1	1015	23
1	1016	1
1	1016	2
1	1016	3
1	1016	5
1	1016	6
1	1016	11
1	1016	12
1	1016	14
1	1016	15
1	1016	16
1	1016	19
1	1016	20
1	1016	21
1	1016	23
1	1016	25
1	1017	1
1	1017	2
1	1017	3
1	1017	4
1	1017	8
1	1017	9
1	1017	10
1	1017	11
1	1017	12
1	1017	15
1	1017	16
1	1017	17
1	1017	19
1	1017	21
1	1017	23
1	1018	2
1	1018	4
1	1018	5
1	1018	7
1	1018	8
1	1018	10
1	1018	11
1	1018	12
1	1018	14
1	1018	16
1	1018	17
1	1018	18
1	1018	19
1	1018	22
1	1018	24
1	1019	1
1	1019	2
1	1019	3
1	1019	4
1	1019	5
1	1019	7
1	1019	8
1	1019	10
1	1019	12
1	1019	17
1	1019	18
1	1019	20
1	1019	21
1	1019	22
1	1019	23
1	1020	2
1	1020	3
1	1020	5
1	1020	7
1	1020	9
1	1020	11
1	1020	12
1	1020	13
1	1020	15
1	1020	16
1	1020	18
1	1020	19
1	1020	20
1	1020	21
1	1020	24
1	1021	1
1	1021	5
1	1021	6
1	1021	9
1	1021	10
1	1021	13
1	1021	14
1	1021	15
1	1021	16
1	1021	18
1	1021	19
1	1021	20
1	1021	21
1	1021	22
1	1021	23
1	1022	1
1	1022	3
1	1022	4
1	1022	5
1	1022	7
1	1022	8
1	1022	9
1	1022	10
1	1022	14
1	1022	16
1	1022	18
1	1022	21
1	1022	22
1	1022	24
1	1022	25
1	1023	1
1	1023	2
1	1023	3
1	1023	6
1	1023	7
1	1023	8
1	1023	9
1	1023	11
1	1023	13
1	1023	14
1	1023	16
1	1023	18
1	1023	21
1	1023	22
1	1023	23
1	1024	1
1	1024	2
1	1024	4
1	1024	7
1	1024	9
1	1024	10
1	1024	11
1	1024	12
1	1024	13
1	1024	14
1	1024	17
1	1024	20
1	1024	21
1	1024	22
1	1024	23
1	1025	1
1	1025	2
1	1025	7
1	1025	9
1	1025	11
1	1025	13
1	1025	14
1	1025	15
1	1025	16
1	1025	17
1	1025	18
1	1025	19
1	1025	22
1	1025	23
1	1025	25
1	1026	1
1	1026	5
1	1026	6
1	1026	7
1	1026	11
1	1026	12
1	1026	14
1	1026	15
1	1026	16
1	1026	18
1	1026	19
1	1026	20
1	1026	21
1	1026	23
1	1026	24
1	1027	1
1	1027	3
1	1027	5
1	1027	6
1	1027	8
1	1027	9
1	1027	10
1	1027	12
1	1027	14
1	1027	15
1	1027	16
1	1027	19
1	1027	21
1	1027	23
1	1027	25
1	1028	4
1	1028	5
1	1028	6
1	1028	7
1	1028	8
1	1028	9
1	1028	10
1	1028	11
1	1028	16
1	1028	17
1	1028	19
1	1028	20
1	1028	23
1	1028	24
1	1028	25
1	1029	1
1	1029	2
1	1029	3
1	1029	6
1	1029	8
1	1029	11
1	1029	13
1	1029	14
1	1029	17
1	1029	18
1	1029	19
1	1029	22
1	1029	23
1	1029	24
1	1029	25
1	1030	1
1	1030	2
1	1030	3
1	1030	4
1	1030	8
1	1030	9
1	1030	10
1	1030	11
1	1030	15
1	1030	16
1	1030	17
1	1030	18
1	1030	19
1	1030	20
1	1030	23
1	1031	1
1	1031	2
1	1031	4
1	1031	5
1	1031	6
1	1031	9
1	1031	11
1	1031	12
1	1031	14
1	1031	15
1	1031	17
1	1031	19
1	1031	20
1	1031	22
1	1031	24
1	1032	1
1	1032	2
1	1032	3
1	1032	4
1	1032	6
1	1032	8
1	1032	10
1	1032	11
1	1032	13
1	1032	14
1	1032	16
1	1032	17
1	1032	18
1	1032	20
1	1032	23
1	1033	3
1	1033	4
1	1033	6
1	1033	7
1	1033	8
1	1033	12
1	1033	13
1	1033	14
1	1033	16
1	1033	17
1	1033	18
1	1033	21
1	1033	22
1	1033	23
1	1033	24
1	1034	2
1	1034	3
1	1034	4
1	1034	6
1	1034	8
1	1034	10
1	1034	12
1	1034	13
1	1034	14
1	1034	17
1	1034	18
1	1034	19
1	1034	20
1	1034	21
1	1034	23
1	1035	4
1	1035	6
1	1035	7
1	1035	9
1	1035	12
1	1035	13
1	1035	14
1	1035	15
1	1035	18
1	1035	19
1	1035	20
1	1035	21
1	1035	22
1	1035	23
1	1035	25
1	1036	4
1	1036	5
1	1036	7
1	1036	9
1	1036	10
1	1036	11
1	1036	12
1	1036	14
1	1036	17
1	1036	18
1	1036	19
1	1036	20
1	1036	21
1	1036	22
1	1036	24
1	1037	1
1	1037	5
1	1037	6
1	1037	9
1	1037	10
1	1037	11
1	1037	12
1	1037	15
1	1037	17
1	1037	18
1	1037	20
1	1037	21
1	1037	23
1	1037	24
1	1037	25
1	1038	2
1	1038	6
1	1038	7
1	1038	8
1	1038	9
1	1038	10
1	1038	13
1	1038	16
1	1038	17
1	1038	18
1	1038	19
1	1038	20
1	1038	21
1	1038	24
1	1038	25
1	1039	1
1	1039	2
1	1039	3
1	1039	8
1	1039	9
1	1039	12
1	1039	13
1	1039	14
1	1039	15
1	1039	18
1	1039	19
1	1039	20
1	1039	21
1	1039	22
1	1039	24
1	1040	1
1	1040	2
1	1040	4
1	1040	6
1	1040	8
1	1040	9
1	1040	10
1	1040	12
1	1040	13
1	1040	16
1	1040	20
1	1040	21
1	1040	22
1	1040	23
1	1040	25
1	1041	1
1	1041	3
1	1041	5
1	1041	7
1	1041	10
1	1041	12
1	1041	13
1	1041	15
1	1041	17
1	1041	19
1	1041	20
1	1041	21
1	1041	23
1	1041	24
1	1041	25
1	1042	1
1	1042	3
1	1042	6
1	1042	7
1	1042	8
1	1042	9
1	1042	10
1	1042	11
1	1042	14
1	1042	15
1	1042	16
1	1042	19
1	1042	21
1	1042	22
1	1042	24
1	1043	1
1	1043	2
1	1043	6
1	1043	7
1	1043	8
1	1043	9
1	1043	10
1	1043	11
1	1043	12
1	1043	14
1	1043	17
1	1043	18
1	1043	19
1	1043	24
1	1043	25
1	1044	2
1	1044	4
1	1044	5
1	1044	6
1	1044	7
1	1044	8
1	1044	10
1	1044	11
1	1044	12
1	1044	15
1	1044	17
1	1044	20
1	1044	23
1	1044	24
1	1044	25
1	1045	2
1	1045	3
1	1045	5
1	1045	6
1	1045	9
1	1045	11
1	1045	15
1	1045	16
1	1045	17
1	1045	20
1	1045	21
1	1045	22
1	1045	23
1	1045	24
1	1045	25
1	1046	3
1	1046	4
1	1046	5
1	1046	7
1	1046	8
1	1046	11
1	1046	12
1	1046	13
1	1046	14
1	1046	18
1	1046	20
1	1046	21
1	1046	22
1	1046	23
1	1046	25
1	1047	4
1	1047	7
1	1047	8
1	1047	9
1	1047	10
1	1047	11
1	1047	12
1	1047	15
1	1047	16
1	1047	17
1	1047	20
1	1047	21
1	1047	22
1	1047	24
1	1047	25
1	1048	1
1	1048	2
1	1048	3
1	1048	5
1	1048	6
1	1048	7
1	1048	9
1	1048	10
1	1048	15
1	1048	16
1	1048	17
1	1048	18
1	1048	20
1	1048	21
1	1048	25
1	1049	2
1	1049	4
1	1049	5
1	1049	9
1	1049	12
1	1049	14
1	1049	16
1	1049	17
1	1049	18
1	1049	19
1	1049	20
1	1049	21
1	1049	22
1	1049	23
1	1049	25
1	1050	1
1	1050	4
1	1050	6
1	1050	7
1	1050	10
1	1050	12
1	1050	13
1	1050	15
1	1050	16
1	1050	17
1	1050	19
1	1050	21
1	1050	22
1	1050	24
1	1050	25
1	1051	2
1	1051	3
1	1051	4
1	1051	7
1	1051	8
1	1051	10
1	1051	11
1	1051	13
1	1051	14
1	1051	16
1	1051	18
1	1051	20
1	1051	21
1	1051	23
1	1051	25
1	1052	1
1	1052	3
1	1052	4
1	1052	5
1	1052	6
1	1052	8
1	1052	10
1	1052	11
1	1052	16
1	1052	17
1	1052	18
1	1052	20
1	1052	21
1	1052	23
1	1052	24
1	1053	1
1	1053	2
1	1053	3
1	1053	4
1	1053	6
1	1053	11
1	1053	12
1	1053	13
1	1053	14
1	1053	15
1	1053	17
1	1053	18
1	1053	22
1	1053	23
1	1053	24
1	1054	2
1	1054	3
1	1054	4
1	1054	5
1	1054	6
1	1054	9
1	1054	12
1	1054	13
1	1054	15
1	1054	16
1	1054	17
1	1054	18
1	1054	20
1	1054	24
1	1054	25
1	1055	1
1	1055	2
1	1055	3
1	1055	7
1	1055	8
1	1055	9
1	1055	10
1	1055	12
1	1055	13
1	1055	14
1	1055	18
1	1055	22
1	1055	23
1	1055	24
1	1055	25
1	1056	2
1	1056	4
1	1056	5
1	1056	6
1	1056	8
1	1056	9
1	1056	10
1	1056	11
1	1056	14
1	1056	15
1	1056	18
1	1056	19
1	1056	21
1	1056	22
1	1056	23
1	1057	1
1	1057	4
1	1057	6
1	1057	7
1	1057	8
1	1057	9
1	1057	11
1	1057	13
1	1057	14
1	1057	16
1	1057	19
1	1057	20
1	1057	21
1	1057	23
1	1057	25
1	1058	4
1	1058	5
1	1058	6
1	1058	7
1	1058	9
1	1058	12
1	1058	13
1	1058	16
1	1058	17
1	1058	18
1	1058	20
1	1058	21
1	1058	22
1	1058	24
1	1058	25
1	1059	1
1	1059	2
1	1059	3
1	1059	5
1	1059	7
1	1059	8
1	1059	11
1	1059	14
1	1059	15
1	1059	16
1	1059	19
1	1059	20
1	1059	21
1	1059	22
1	1059	24
1	1060	1
1	1060	2
1	1060	4
1	1060	5
1	1060	7
1	1060	8
1	1060	13
1	1060	14
1	1060	15
1	1060	16
1	1060	17
1	1060	20
1	1060	21
1	1060	22
1	1060	23
1	1061	2
1	1061	3
1	1061	5
1	1061	7
1	1061	8
1	1061	9
1	1061	12
1	1061	14
1	1061	15
1	1061	16
1	1061	19
1	1061	21
1	1061	22
1	1061	23
1	1061	24
1	1062	3
1	1062	4
1	1062	5
1	1062	7
1	1062	8
1	1062	9
1	1062	11
1	1062	13
1	1062	15
1	1062	16
1	1062	17
1	1062	19
1	1062	20
1	1062	23
1	1062	25
1	1063	2
1	1063	5
1	1063	6
1	1063	7
1	1063	10
1	1063	12
1	1063	13
1	1063	14
1	1063	15
1	1063	16
1	1063	20
1	1063	21
1	1063	22
1	1063	24
1	1063	25
1	1064	2
1	1064	3
1	1064	7
1	1064	8
1	1064	9
1	1064	10
1	1064	11
1	1064	14
1	1064	15
1	1064	16
1	1064	18
1	1064	19
1	1064	21
1	1064	24
1	1064	25
1	1065	2
1	1065	3
1	1065	4
1	1065	5
1	1065	6
1	1065	12
1	1065	14
1	1065	15
1	1065	17
1	1065	19
1	1065	20
1	1065	21
1	1065	22
1	1065	24
1	1065	25
1	1066	2
1	1066	4
1	1066	5
1	1066	6
1	1066	10
1	1066	11
1	1066	14
1	1066	16
1	1066	17
1	1066	18
1	1066	19
1	1066	21
1	1066	22
1	1066	23
1	1066	24
1	1067	1
1	1067	2
1	1067	3
1	1067	4
1	1067	5
1	1067	7
1	1067	10
1	1067	11
1	1067	13
1	1067	14
1	1067	15
1	1067	17
1	1067	21
1	1067	22
1	1067	25
1	1068	2
1	1068	6
1	1068	7
1	1068	10
1	1068	11
1	1068	13
1	1068	14
1	1068	15
1	1068	16
1	1068	17
1	1068	18
1	1068	20
1	1068	21
1	1068	22
1	1068	24
1	1069	1
1	1069	3
1	1069	4
1	1069	8
1	1069	10
1	1069	11
1	1069	12
1	1069	13
1	1069	15
1	1069	16
1	1069	17
1	1069	22
1	1069	23
1	1069	24
1	1069	25
1	1070	4
1	1070	9
1	1070	10
1	1070	11
1	1070	12
1	1070	13
1	1070	16
1	1070	18
1	1070	19
1	1070	20
1	1070	21
1	1070	22
1	1070	23
1	1070	24
1	1070	25
1	1071	2
1	1071	3
1	1071	4
1	1071	5
1	1071	6
1	1071	10
1	1071	11
1	1071	12
1	1071	13
1	1071	14
1	1071	16
1	1071	17
1	1071	21
1	1071	22
1	1071	24
1	1072	1
1	1072	2
1	1072	3
1	1072	4
1	1072	5
1	1072	7
1	1072	9
1	1072	13
1	1072	14
1	1072	15
1	1072	17
1	1072	20
1	1072	22
1	1072	23
1	1072	25
1	1073	1
1	1073	3
1	1073	4
1	1073	5
1	1073	6
1	1073	7
1	1073	13
1	1073	16
1	1073	17
1	1073	19
1	1073	20
1	1073	21
1	1073	22
1	1073	23
1	1073	24
1	1074	1
1	1074	4
1	1074	7
1	1074	8
1	1074	9
1	1074	10
1	1074	11
1	1074	13
1	1074	17
1	1074	20
1	1074	21
1	1074	22
1	1074	23
1	1074	24
1	1074	25
1	1075	1
1	1075	2
1	1075	6
1	1075	9
1	1075	10
1	1075	12
1	1075	15
1	1075	16
1	1075	17
1	1075	18
1	1075	21
1	1075	22
1	1075	23
1	1075	24
1	1075	25
1	1076	4
1	1076	9
1	1076	10
1	1076	11
1	1076	12
1	1076	13
1	1076	14
1	1076	15
1	1076	16
1	1076	17
1	1076	18
1	1076	20
1	1076	21
1	1076	22
1	1076	25
1	1077	1
1	1077	2
1	1077	5
1	1077	6
1	1077	7
1	1077	8
1	1077	10
1	1077	12
1	1077	13
1	1077	14
1	1077	15
1	1077	19
1	1077	20
1	1077	21
1	1077	24
1	1078	2
1	1078	4
1	1078	5
1	1078	6
1	1078	7
1	1078	9
1	1078	10
1	1078	11
1	1078	13
1	1078	17
1	1078	18
1	1078	21
1	1078	23
1	1078	24
1	1078	25
1	1079	5
1	1079	6
1	1079	7
1	1079	8
1	1079	11
1	1079	13
1	1079	14
1	1079	15
1	1079	16
1	1079	17
1	1079	19
1	1079	20
1	1079	21
1	1079	22
1	1079	24
1	1080	2
1	1080	3
1	1080	5
1	1080	6
1	1080	10
1	1080	11
1	1080	12
1	1080	14
1	1080	15
1	1080	16
1	1080	17
1	1080	21
1	1080	22
1	1080	23
1	1080	25
1	1081	1
1	1081	5
1	1081	6
1	1081	7
1	1081	10
1	1081	12
1	1081	13
1	1081	14
1	1081	15
1	1081	16
1	1081	18
1	1081	19
1	1081	21
1	1081	22
1	1081	23
1	1082	3
1	1082	7
1	1082	9
1	1082	10
1	1082	11
1	1082	13
1	1082	15
1	1082	16
1	1082	17
1	1082	18
1	1082	19
1	1082	21
1	1082	22
1	1082	23
1	1082	24
1	1083	1
1	1083	2
1	1083	3
1	1083	4
1	1083	6
1	1083	11
1	1083	13
1	1083	16
1	1083	17
1	1083	18
1	1083	20
1	1083	21
1	1083	22
1	1083	23
1	1083	24
1	1084	1
1	1084	2
1	1084	3
1	1084	4
1	1084	5
1	1084	6
1	1084	7
1	1084	9
1	1084	10
1	1084	13
1	1084	17
1	1084	18
1	1084	21
1	1084	24
1	1084	25
1	1085	3
1	1085	6
1	1085	7
1	1085	8
1	1085	9
1	1085	10
1	1085	14
1	1085	16
1	1085	18
1	1085	19
1	1085	21
1	1085	22
1	1085	23
1	1085	24
1	1085	25
1	1086	2
1	1086	4
1	1086	5
1	1086	7
1	1086	10
1	1086	12
1	1086	13
1	1086	15
1	1086	17
1	1086	18
1	1086	19
1	1086	21
1	1086	22
1	1086	23
1	1086	24
1	1087	2
1	1087	3
1	1087	4
1	1087	6
1	1087	9
1	1087	12
1	1087	13
1	1087	16
1	1087	17
1	1087	18
1	1087	19
1	1087	20
1	1087	21
1	1087	23
1	1087	24
1	1088	1
1	1088	2
1	1088	3
1	1088	5
1	1088	6
1	1088	7
1	1088	9
1	1088	10
1	1088	12
1	1088	13
1	1088	18
1	1088	19
1	1088	20
1	1088	22
1	1088	23
1	1089	2
1	1089	3
1	1089	4
1	1089	6
1	1089	8
1	1089	12
1	1089	13
1	1089	14
1	1089	15
1	1089	16
1	1089	19
1	1089	21
1	1089	22
1	1089	23
1	1089	24
1	1090	3
1	1090	5
1	1090	8
1	1090	9
1	1090	10
1	1090	11
1	1090	13
1	1090	14
1	1090	15
1	1090	17
1	1090	18
1	1090	20
1	1090	21
1	1090	22
1	1090	24
1	1091	2
1	1091	4
1	1091	5
1	1091	6
1	1091	7
1	1091	9
1	1091	10
1	1091	12
1	1091	13
1	1091	14
1	1091	16
1	1091	20
1	1091	23
1	1091	24
1	1091	25
1	1092	4
1	1092	5
1	1092	8
1	1092	9
1	1092	11
1	1092	12
1	1092	13
1	1092	14
1	1092	15
1	1092	18
1	1092	19
1	1092	20
1	1092	22
1	1092	24
1	1092	25
1	1093	1
1	1093	2
1	1093	4
1	1093	5
1	1093	6
1	1093	9
1	1093	10
1	1093	11
1	1093	13
1	1093	18
1	1093	21
1	1093	22
1	1093	23
1	1093	24
1	1093	25
1	1094	1
1	1094	2
1	1094	3
1	1094	4
1	1094	5
1	1094	6
1	1094	8
1	1094	9
1	1094	10
1	1094	12
1	1094	14
1	1094	16
1	1094	19
1	1094	22
1	1094	25
1	1095	2
1	1095	3
1	1095	5
1	1095	6
1	1095	7
1	1095	9
1	1095	15
1	1095	16
1	1095	17
1	1095	18
1	1095	21
1	1095	22
1	1095	23
1	1095	24
1	1095	25
1	1096	1
1	1096	2
1	1096	4
1	1096	7
1	1096	8
1	1096	10
1	1096	12
1	1096	13
1	1096	14
1	1096	15
1	1096	20
1	1096	21
1	1096	22
1	1096	23
1	1096	25
1	1097	4
1	1097	5
1	1097	6
1	1097	9
1	1097	10
1	1097	12
1	1097	14
1	1097	15
1	1097	16
1	1097	18
1	1097	19
1	1097	20
1	1097	23
1	1097	24
1	1097	25
1	1098	3
1	1098	4
1	1098	5
1	1098	7
1	1098	8
1	1098	10
1	1098	11
1	1098	12
1	1098	14
1	1098	15
1	1098	16
1	1098	18
1	1098	23
1	1098	24
1	1098	25
1	1099	2
1	1099	3
1	1099	6
1	1099	7
1	1099	8
1	1099	11
1	1099	12
1	1099	13
1	1099	14
1	1099	16
1	1099	21
1	1099	22
1	1099	23
1	1099	24
1	1099	25
1	1100	5
1	1100	6
1	1100	7
1	1100	9
1	1100	10
1	1100	11
1	1100	12
1	1100	14
1	1100	15
1	1100	16
1	1100	18
1	1100	19
1	1100	20
1	1100	23
1	1100	24
1	1101	1
1	1101	2
1	1101	3
1	1101	6
1	1101	9
1	1101	10
1	1101	11
1	1101	13
1	1101	15
1	1101	17
1	1101	18
1	1101	19
1	1101	23
1	1101	24
1	1101	25
1	1102	2
1	1102	3
1	1102	5
1	1102	6
1	1102	8
1	1102	12
1	1102	14
1	1102	15
1	1102	18
1	1102	19
1	1102	20
1	1102	21
1	1102	22
1	1102	23
1	1102	24
1	1103	2
1	1103	4
1	1103	5
1	1103	7
1	1103	9
1	1103	10
1	1103	11
1	1103	12
1	1103	14
1	1103	16
1	1103	18
1	1103	20
1	1103	21
1	1103	22
1	1103	25
1	1104	2
1	1104	5
1	1104	6
1	1104	8
1	1104	9
1	1104	11
1	1104	13
1	1104	14
1	1104	15
1	1104	16
1	1104	18
1	1104	19
1	1104	21
1	1104	22
1	1104	23
1	1105	1
1	1105	2
1	1105	4
1	1105	6
1	1105	7
1	1105	9
1	1105	11
1	1105	13
1	1105	15
1	1105	17
1	1105	18
1	1105	20
1	1105	23
1	1105	24
1	1105	25
1	1106	2
1	1106	3
1	1106	4
1	1106	9
1	1106	10
1	1106	11
1	1106	12
1	1106	13
1	1106	14
1	1106	15
1	1106	16
1	1106	19
1	1106	21
1	1106	23
1	1106	24
1	1107	1
1	1107	2
1	1107	4
1	1107	8
1	1107	9
1	1107	10
1	1107	11
1	1107	12
1	1107	14
1	1107	16
1	1107	18
1	1107	19
1	1107	20
1	1107	21
1	1107	24
1	1108	1
1	1108	2
1	1108	4
1	1108	5
1	1108	7
1	1108	8
1	1108	9
1	1108	12
1	1108	13
1	1108	14
1	1108	17
1	1108	21
1	1108	22
1	1108	24
1	1108	25
1	1109	1
1	1109	4
1	1109	5
1	1109	6
1	1109	7
1	1109	8
1	1109	9
1	1109	10
1	1109	11
1	1109	17
1	1109	18
1	1109	19
1	1109	20
1	1109	21
1	1109	25
1	1110	1
1	1110	2
1	1110	3
1	1110	4
1	1110	6
1	1110	9
1	1110	10
1	1110	15
1	1110	17
1	1110	18
1	1110	19
1	1110	20
1	1110	22
1	1110	24
1	1110	25
1	1111	2
1	1111	3
1	1111	4
1	1111	6
1	1111	9
1	1111	11
1	1111	12
1	1111	13
1	1111	14
1	1111	15
1	1111	16
1	1111	22
1	1111	23
1	1111	24
1	1111	25
1	1112	1
1	1112	2
1	1112	3
1	1112	6
1	1112	7
1	1112	8
1	1112	12
1	1112	13
1	1112	15
1	1112	16
1	1112	17
1	1112	18
1	1112	20
1	1112	22
1	1112	24
1	1113	1
1	1113	3
1	1113	6
1	1113	7
1	1113	9
1	1113	12
1	1113	13
1	1113	14
1	1113	15
1	1113	17
1	1113	19
1	1113	20
1	1113	22
1	1113	24
1	1113	25
1	1114	1
1	1114	2
1	1114	3
1	1114	4
1	1114	5
1	1114	6
1	1114	8
1	1114	10
1	1114	11
1	1114	12
1	1114	15
1	1114	18
1	1114	19
1	1114	20
1	1114	22
1	1115	2
1	1115	3
1	1115	7
1	1115	8
1	1115	9
1	1115	10
1	1115	11
1	1115	12
1	1115	17
1	1115	18
1	1115	20
1	1115	22
1	1115	23
1	1115	24
1	1115	25
1	1116	1
1	1116	2
1	1116	3
1	1116	4
1	1116	5
1	1116	6
1	1116	9
1	1116	12
1	1116	15
1	1116	17
1	1116	18
1	1116	21
1	1116	22
1	1116	24
1	1116	25
1	1117	1
1	1117	2
1	1117	3
1	1117	5
1	1117	7
1	1117	8
1	1117	11
1	1117	12
1	1117	13
1	1117	14
1	1117	15
1	1117	16
1	1117	19
1	1117	21
1	1117	23
1	1118	1
1	1118	2
1	1118	5
1	1118	6
1	1118	8
1	1118	10
1	1118	11
1	1118	13
1	1118	14
1	1118	15
1	1118	20
1	1118	21
1	1118	23
1	1118	24
1	1118	25
1	1119	1
1	1119	2
1	1119	3
1	1119	5
1	1119	6
1	1119	7
1	1119	8
1	1119	10
1	1119	12
1	1119	14
1	1119	15
1	1119	17
1	1119	18
1	1119	20
1	1119	23
1	1120	2
1	1120	4
1	1120	5
1	1120	6
1	1120	8
1	1120	9
1	1120	10
1	1120	12
1	1120	13
1	1120	14
1	1120	16
1	1120	17
1	1120	18
1	1120	19
1	1120	24
1	1121	1
1	1121	2
1	1121	4
1	1121	5
1	1121	6
1	1121	8
1	1121	9
1	1121	11
1	1121	12
1	1121	17
1	1121	18
1	1121	20
1	1121	22
1	1121	23
1	1121	25
1	1122	2
1	1122	3
1	1122	7
1	1122	10
1	1122	11
1	1122	12
1	1122	13
1	1122	14
1	1122	16
1	1122	19
1	1122	20
1	1122	21
1	1122	23
1	1122	24
1	1122	25
1	1123	2
1	1123	4
1	1123	6
1	1123	7
1	1123	8
1	1123	10
1	1123	11
1	1123	13
1	1123	15
1	1123	16
1	1123	17
1	1123	19
1	1123	22
1	1123	23
1	1123	24
1	1124	1
1	1124	3
1	1124	4
1	1124	5
1	1124	6
1	1124	8
1	1124	10
1	1124	12
1	1124	13
1	1124	15
1	1124	19
1	1124	21
1	1124	22
1	1124	24
1	1124	25
1	1125	1
1	1125	3
1	1125	4
1	1125	6
1	1125	9
1	1125	11
1	1125	12
1	1125	13
1	1125	15
1	1125	16
1	1125	17
1	1125	18
1	1125	21
1	1125	22
1	1125	25
1	1126	3
1	1126	5
1	1126	6
1	1126	7
1	1126	8
1	1126	12
1	1126	13
1	1126	16
1	1126	17
1	1126	18
1	1126	19
1	1126	22
1	1126	23
1	1126	24
1	1126	25
1	1127	1
1	1127	3
1	1127	4
1	1127	6
1	1127	8
1	1127	9
1	1127	11
1	1127	13
1	1127	14
1	1127	15
1	1127	16
1	1127	17
1	1127	22
1	1127	23
1	1127	24
1	1128	1
1	1128	2
1	1128	3
1	1128	4
1	1128	6
1	1128	7
1	1128	10
1	1128	11
1	1128	12
1	1128	14
1	1128	16
1	1128	17
1	1128	20
1	1128	24
1	1128	25
1	1129	2
1	1129	3
1	1129	4
1	1129	5
1	1129	7
1	1129	8
1	1129	12
1	1129	13
1	1129	16
1	1129	17
1	1129	18
1	1129	19
1	1129	21
1	1129	22
1	1129	23
1	1130	1
1	1130	2
1	1130	5
1	1130	8
1	1130	10
1	1130	11
1	1130	12
1	1130	13
1	1130	14
1	1130	15
1	1130	17
1	1130	20
1	1130	22
1	1130	24
1	1130	25
1	1131	2
1	1131	3
1	1131	4
1	1131	6
1	1131	12
1	1131	14
1	1131	15
1	1131	16
1	1131	17
1	1131	19
1	1131	20
1	1131	21
1	1131	22
1	1131	24
1	1131	25
1	1132	1
1	1132	2
1	1132	6
1	1132	7
1	1132	8
1	1132	9
1	1132	11
1	1132	12
1	1132	13
1	1132	14
1	1132	17
1	1132	21
1	1132	22
1	1132	23
1	1132	24
1	1133	2
1	1133	4
1	1133	5
1	1133	6
1	1133	7
1	1133	8
1	1133	9
1	1133	10
1	1133	12
1	1133	13
1	1133	14
1	1133	16
1	1133	18
1	1133	24
1	1133	25
1	1134	1
1	1134	2
1	1134	4
1	1134	8
1	1134	10
1	1134	11
1	1134	12
1	1134	13
1	1134	14
1	1134	15
1	1134	17
1	1134	18
1	1134	20
1	1134	23
1	1134	25
1	1135	3
1	1135	4
1	1135	5
1	1135	8
1	1135	9
1	1135	10
1	1135	12
1	1135	15
1	1135	16
1	1135	17
1	1135	18
1	1135	19
1	1135	23
1	1135	24
1	1135	25
1	1136	1
1	1136	2
1	1136	5
1	1136	6
1	1136	7
1	1136	9
1	1136	10
1	1136	11
1	1136	15
1	1136	17
1	1136	18
1	1136	19
1	1136	21
1	1136	22
1	1136	24
1	1137	2
1	1137	4
1	1137	5
1	1137	7
1	1137	8
1	1137	9
1	1137	10
1	1137	11
1	1137	12
1	1137	15
1	1137	19
1	1137	20
1	1137	21
1	1137	23
1	1137	25
1	1138	1
1	1138	2
1	1138	3
1	1138	5
1	1138	6
1	1138	7
1	1138	10
1	1138	11
1	1138	13
1	1138	15
1	1138	16
1	1138	18
1	1138	20
1	1138	21
1	1138	22
1	1139	1
1	1139	2
1	1139	3
1	1139	6
1	1139	11
1	1139	13
1	1139	14
1	1139	15
1	1139	16
1	1139	17
1	1139	18
1	1139	19
1	1139	21
1	1139	22
1	1139	25
1	1140	3
1	1140	4
1	1140	5
1	1140	6
1	1140	7
1	1140	8
1	1140	10
1	1140	15
1	1140	18
1	1140	19
1	1140	20
1	1140	21
1	1140	23
1	1140	24
1	1140	25
1	1141	5
1	1141	6
1	1141	9
1	1141	10
1	1141	11
1	1141	12
1	1141	13
1	1141	15
1	1141	16
1	1141	17
1	1141	18
1	1141	22
1	1141	23
1	1141	24
1	1141	25
1	1142	2
1	1142	4
1	1142	7
1	1142	8
1	1142	9
1	1142	10
1	1142	12
1	1142	13
1	1142	15
1	1142	16
1	1142	19
1	1142	20
1	1142	22
1	1142	23
1	1142	24
1	1143	1
1	1143	3
1	1143	4
1	1143	6
1	1143	10
1	1143	11
1	1143	12
1	1143	13
1	1143	14
1	1143	16
1	1143	17
1	1143	18
1	1143	23
1	1143	24
1	1143	25
1	1144	2
1	1144	3
1	1144	4
1	1144	6
1	1144	7
1	1144	8
1	1144	10
1	1144	13
1	1144	14
1	1144	17
1	1144	18
1	1144	19
1	1144	23
1	1144	24
1	1144	25
1	1145	3
1	1145	4
1	1145	5
1	1145	6
1	1145	8
1	1145	9
1	1145	11
1	1145	13
1	1145	14
1	1145	15
1	1145	16
1	1145	17
1	1145	18
1	1145	23
1	1145	24
1	1146	2
1	1146	3
1	1146	4
1	1146	5
1	1146	7
1	1146	11
1	1146	13
1	1146	15
1	1146	17
1	1146	18
1	1146	19
1	1146	21
1	1146	22
1	1146	24
1	1146	25
1	1147	1
1	1147	6
1	1147	7
1	1147	8
1	1147	9
1	1147	11
1	1147	12
1	1147	14
1	1147	15
1	1147	16
1	1147	18
1	1147	19
1	1147	20
1	1147	22
1	1147	25
1	1148	1
1	1148	3
1	1148	4
1	1148	5
1	1148	6
1	1148	9
1	1148	10
1	1148	13
1	1148	14
1	1148	16
1	1148	17
1	1148	18
1	1148	19
1	1148	20
1	1148	24
1	1149	1
1	1149	2
1	1149	3
1	1149	6
1	1149	7
1	1149	8
1	1149	10
1	1149	12
1	1149	15
1	1149	17
1	1149	18
1	1149	19
1	1149	21
1	1149	22
1	1149	23
1	1150	5
1	1150	7
1	1150	8
1	1150	9
1	1150	11
1	1150	12
1	1150	13
1	1150	14
1	1150	15
1	1150	17
1	1150	18
1	1150	20
1	1150	22
1	1150	23
1	1150	24
1	1151	1
1	1151	3
1	1151	7
1	1151	9
1	1151	10
1	1151	11
1	1151	12
1	1151	14
1	1151	15
1	1151	16
1	1151	20
1	1151	21
1	1151	22
1	1151	24
1	1151	25
1	1152	3
1	1152	4
1	1152	5
1	1152	7
1	1152	8
1	1152	9
1	1152	10
1	1152	12
1	1152	16
1	1152	18
1	1152	19
1	1152	20
1	1152	21
1	1152	22
1	1152	25
1	1153	1
1	1153	2
1	1153	3
1	1153	5
1	1153	6
1	1153	8
1	1153	9
1	1153	12
1	1153	13
1	1153	15
1	1153	18
1	1153	19
1	1153	20
1	1153	24
1	1153	25
1	1154	1
1	1154	3
1	1154	4
1	1154	5
1	1154	10
1	1154	11
1	1154	13
1	1154	15
1	1154	16
1	1154	17
1	1154	19
1	1154	21
1	1154	23
1	1154	24
1	1154	25
1	1155	1
1	1155	2
1	1155	3
1	1155	4
1	1155	8
1	1155	9
1	1155	12
1	1155	13
1	1155	15
1	1155	16
1	1155	18
1	1155	19
1	1155	22
1	1155	24
1	1155	25
1	1156	1
1	1156	3
1	1156	4
1	1156	6
1	1156	7
1	1156	11
1	1156	12
1	1156	13
1	1156	14
1	1156	15
1	1156	17
1	1156	21
1	1156	22
1	1156	24
1	1156	25
1	1157	2
1	1157	4
1	1157	5
1	1157	6
1	1157	7
1	1157	8
1	1157	11
1	1157	12
1	1157	13
1	1157	15
1	1157	16
1	1157	18
1	1157	21
1	1157	22
1	1157	24
1	1158	2
1	1158	3
1	1158	5
1	1158	7
1	1158	10
1	1158	13
1	1158	14
1	1158	15
1	1158	16
1	1158	17
1	1158	19
1	1158	20
1	1158	22
1	1158	24
1	1158	25
1	1159	1
1	1159	2
1	1159	3
1	1159	4
1	1159	6
1	1159	8
1	1159	9
1	1159	14
1	1159	15
1	1159	16
1	1159	17
1	1159	22
1	1159	23
1	1159	24
1	1159	25
1	1160	2
1	1160	4
1	1160	5
1	1160	6
1	1160	7
1	1160	8
1	1160	10
1	1160	11
1	1160	15
1	1160	16
1	1160	17
1	1160	18
1	1160	21
1	1160	22
1	1160	25
1	1161	1
1	1161	2
1	1161	4
1	1161	5
1	1161	6
1	1161	8
1	1161	10
1	1161	11
1	1161	15
1	1161	17
1	1161	18
1	1161	19
1	1161	22
1	1161	24
1	1161	25
1	1162	1
1	1162	3
1	1162	4
1	1162	7
1	1162	9
1	1162	11
1	1162	13
1	1162	15
1	1162	18
1	1162	19
1	1162	20
1	1162	21
1	1162	23
1	1162	24
1	1162	25
1	1163	2
1	1163	6
1	1163	7
1	1163	9
1	1163	11
1	1163	12
1	1163	13
1	1163	14
1	1163	16
1	1163	17
1	1163	19
1	1163	20
1	1163	21
1	1163	23
1	1163	24
1	1164	3
1	1164	4
1	1164	5
1	1164	8
1	1164	10
1	1164	11
1	1164	13
1	1164	15
1	1164	17
1	1164	20
1	1164	21
1	1164	22
1	1164	23
1	1164	24
1	1164	25
1	1165	1
1	1165	2
1	1165	3
1	1165	5
1	1165	8
1	1165	9
1	1165	10
1	1165	12
1	1165	15
1	1165	17
1	1165	18
1	1165	19
1	1165	21
1	1165	22
1	1165	25
1	1166	2
1	1166	4
1	1166	5
1	1166	6
1	1166	9
1	1166	10
1	1166	12
1	1166	14
1	1166	15
1	1166	17
1	1166	18
1	1166	19
1	1166	20
1	1166	21
1	1166	24
1	1167	1
1	1167	2
1	1167	4
1	1167	5
1	1167	7
1	1167	8
1	1167	9
1	1167	11
1	1167	12
1	1167	14
1	1167	15
1	1167	16
1	1167	18
1	1167	21
1	1167	23
1	1168	1
1	1168	3
1	1168	4
1	1168	5
1	1168	7
1	1168	8
1	1168	9
1	1168	10
1	1168	11
1	1168	13
1	1168	16
1	1168	19
1	1168	23
1	1168	24
1	1168	25
1	1169	2
1	1169	3
1	1169	4
1	1169	7
1	1169	8
1	1169	9
1	1169	12
1	1169	15
1	1169	16
1	1169	17
1	1169	18
1	1169	21
1	1169	22
1	1169	24
1	1169	25
1	1170	1
1	1170	2
1	1170	4
1	1170	7
1	1170	8
1	1170	10
1	1170	13
1	1170	15
1	1170	16
1	1170	18
1	1170	19
1	1170	20
1	1170	21
1	1170	22
1	1170	25
1	1171	1
1	1171	7
1	1171	8
1	1171	11
1	1171	12
1	1171	13
1	1171	14
1	1171	15
1	1171	16
1	1171	17
1	1171	18
1	1171	20
1	1171	21
1	1171	22
1	1171	23
1	1172	2
1	1172	6
1	1172	8
1	1172	9
1	1172	10
1	1172	11
1	1172	12
1	1172	13
1	1172	14
1	1172	16
1	1172	19
1	1172	20
1	1172	23
1	1172	24
1	1172	25
1	1173	1
1	1173	2
1	1173	4
1	1173	5
1	1173	7
1	1173	8
1	1173	9
1	1173	11
1	1173	14
1	1173	16
1	1173	18
1	1173	19
1	1173	20
1	1173	21
1	1173	22
1	1174	1
1	1174	2
1	1174	3
1	1174	5
1	1174	6
1	1174	8
1	1174	9
1	1174	10
1	1174	11
1	1174	13
1	1174	15
1	1174	17
1	1174	18
1	1174	19
1	1174	23
1	1175	1
1	1175	3
1	1175	4
1	1175	8
1	1175	10
1	1175	12
1	1175	13
1	1175	14
1	1175	15
1	1175	19
1	1175	20
1	1175	21
1	1175	23
1	1175	24
1	1175	25
1	1176	2
1	1176	3
1	1176	5
1	1176	7
1	1176	10
1	1176	11
1	1176	12
1	1176	13
1	1176	15
1	1176	16
1	1176	18
1	1176	19
1	1176	20
1	1176	23
1	1176	25
1	1177	2
1	1177	3
1	1177	5
1	1177	6
1	1177	8
1	1177	9
1	1177	10
1	1177	11
1	1177	12
1	1177	16
1	1177	17
1	1177	20
1	1177	22
1	1177	23
1	1177	25
1	1178	1
1	1178	4
1	1178	7
1	1178	8
1	1178	9
1	1178	11
1	1178	12
1	1178	16
1	1178	17
1	1178	18
1	1178	19
1	1178	20
1	1178	21
1	1178	23
1	1178	24
1	1179	1
1	1179	2
1	1179	3
1	1179	5
1	1179	6
1	1179	7
1	1179	8
1	1179	9
1	1179	13
1	1179	15
1	1179	18
1	1179	19
1	1179	20
1	1179	21
1	1179	25
1	1180	1
1	1180	2
1	1180	6
1	1180	7
1	1180	8
1	1180	9
1	1180	10
1	1180	11
1	1180	13
1	1180	14
1	1180	15
1	1180	19
1	1180	20
1	1180	22
1	1180	23
1	1181	3
1	1181	4
1	1181	5
1	1181	6
1	1181	7
1	1181	8
1	1181	9
1	1181	11
1	1181	13
1	1181	14
1	1181	20
1	1181	21
1	1181	22
1	1181	23
1	1181	24
1	1182	3
1	1182	6
1	1182	7
1	1182	8
1	1182	10
1	1182	12
1	1182	13
1	1182	16
1	1182	18
1	1182	19
1	1182	20
1	1182	21
1	1182	22
1	1182	24
1	1182	25
1	1183	1
1	1183	3
1	1183	4
1	1183	9
1	1183	11
1	1183	13
1	1183	14
1	1183	15
1	1183	16
1	1183	18
1	1183	19
1	1183	20
1	1183	22
1	1183	24
1	1183	25
1	1184	2
1	1184	4
1	1184	6
1	1184	7
1	1184	10
1	1184	11
1	1184	12
1	1184	14
1	1184	16
1	1184	17
1	1184	18
1	1184	19
1	1184	20
1	1184	21
1	1184	25
1	1185	3
1	1185	5
1	1185	6
1	1185	7
1	1185	9
1	1185	13
1	1185	14
1	1185	16
1	1185	18
1	1185	19
1	1185	21
1	1185	22
1	1185	23
1	1185	24
1	1185	25
1	1186	1
1	1186	2
1	1186	4
1	1186	5
1	1186	6
1	1186	9
1	1186	11
1	1186	14
1	1186	15
1	1186	16
1	1186	18
1	1186	20
1	1186	22
1	1186	23
1	1186	24
1	1187	1
1	1187	2
1	1187	4
1	1187	7
1	1187	8
1	1187	10
1	1187	11
1	1187	12
1	1187	14
1	1187	16
1	1187	19
1	1187	21
1	1187	22
1	1187	23
1	1187	25
1	1188	1
1	1188	2
1	1188	4
1	1188	5
1	1188	6
1	1188	8
1	1188	10
1	1188	12
1	1188	13
1	1188	14
1	1188	18
1	1188	20
1	1188	22
1	1188	23
1	1188	24
1	1189	3
1	1189	4
1	1189	5
1	1189	8
1	1189	9
1	1189	12
1	1189	13
1	1189	14
1	1189	15
1	1189	17
1	1189	18
1	1189	19
1	1189	20
1	1189	21
1	1189	25
1	1190	2
1	1190	3
1	1190	4
1	1190	6
1	1190	9
1	1190	10
1	1190	11
1	1190	14
1	1190	15
1	1190	16
1	1190	17
1	1190	21
1	1190	22
1	1190	23
1	1190	25
1	1191	1
1	1191	2
1	1191	3
1	1191	5
1	1191	7
1	1191	10
1	1191	12
1	1191	13
1	1191	14
1	1191	16
1	1191	17
1	1191	18
1	1191	22
1	1191	24
1	1191	25
1	1192	1
1	1192	2
1	1192	3
1	1192	4
1	1192	5
1	1192	6
1	1192	9
1	1192	11
1	1192	12
1	1192	13
1	1192	15
1	1192	16
1	1192	19
1	1192	20
1	1192	21
1	1193	1
1	1193	4
1	1193	7
1	1193	8
1	1193	9
1	1193	10
1	1193	13
1	1193	14
1	1193	15
1	1193	18
1	1193	19
1	1193	20
1	1193	22
1	1193	23
1	1193	25
1	1194	2
1	1194	4
1	1194	8
1	1194	9
1	1194	10
1	1194	12
1	1194	15
1	1194	16
1	1194	17
1	1194	18
1	1194	19
1	1194	22
1	1194	23
1	1194	24
1	1194	25
1	1195	1
1	1195	5
1	1195	6
1	1195	9
1	1195	10
1	1195	11
1	1195	12
1	1195	14
1	1195	15
1	1195	17
1	1195	18
1	1195	19
1	1195	20
1	1195	22
1	1195	25
1	1196	1
1	1196	2
1	1196	4
1	1196	6
1	1196	7
1	1196	8
1	1196	9
1	1196	11
1	1196	12
1	1196	16
1	1196	17
1	1196	18
1	1196	19
1	1196	20
1	1196	23
1	1197	1
1	1197	4
1	1197	5
1	1197	6
1	1197	7
1	1197	8
1	1197	11
1	1197	13
1	1197	14
1	1197	16
1	1197	17
1	1197	18
1	1197	20
1	1197	24
1	1197	25
1	1198	1
1	1198	3
1	1198	4
1	1198	6
1	1198	7
1	1198	9
1	1198	10
1	1198	11
1	1198	15
1	1198	17
1	1198	20
1	1198	21
1	1198	22
1	1198	23
1	1198	25
1	1199	1
1	1199	2
1	1199	3
1	1199	4
1	1199	5
1	1199	6
1	1199	10
1	1199	14
1	1199	15
1	1199	16
1	1199	19
1	1199	21
1	1199	22
1	1199	24
1	1199	25
1	1200	3
1	1200	4
1	1200	5
1	1200	6
1	1200	7
1	1200	8
1	1200	10
1	1200	11
1	1200	12
1	1200	14
1	1200	15
1	1200	16
1	1200	22
1	1200	24
1	1200	25
1	1201	5
1	1201	6
1	1201	9
1	1201	10
1	1201	11
1	1201	14
1	1201	16
1	1201	18
1	1201	19
1	1201	20
1	1201	21
1	1201	22
1	1201	23
1	1201	24
1	1201	25
1	1202	2
1	1202	3
1	1202	4
1	1202	8
1	1202	10
1	1202	13
1	1202	14
1	1202	16
1	1202	17
1	1202	18
1	1202	19
1	1202	20
1	1202	23
1	1202	24
1	1202	25
1	1203	1
1	1203	2
1	1203	3
1	1203	5
1	1203	6
1	1203	11
1	1203	12
1	1203	13
1	1203	14
1	1203	15
1	1203	17
1	1203	22
1	1203	23
1	1203	24
1	1203	25
1	1204	1
1	1204	2
1	1204	5
1	1204	7
1	1204	8
1	1204	9
1	1204	12
1	1204	13
1	1204	15
1	1204	16
1	1204	19
1	1204	20
1	1204	21
1	1204	22
1	1204	23
1	1205	1
1	1205	3
1	1205	6
1	1205	8
1	1205	9
1	1205	11
1	1205	12
1	1205	14
1	1205	17
1	1205	18
1	1205	20
1	1205	21
1	1205	22
1	1205	24
1	1205	25
1	1206	1
1	1206	3
1	1206	5
1	1206	7
1	1206	10
1	1206	11
1	1206	13
1	1206	14
1	1206	15
1	1206	18
1	1206	21
1	1206	22
1	1206	23
1	1206	24
1	1206	25
1	1207	1
1	1207	3
1	1207	4
1	1207	7
1	1207	9
1	1207	10
1	1207	11
1	1207	12
1	1207	13
1	1207	14
1	1207	15
1	1207	18
1	1207	19
1	1207	21
1	1207	24
1	1208	1
1	1208	2
1	1208	3
1	1208	4
1	1208	5
1	1208	10
1	1208	11
1	1208	14
1	1208	15
1	1208	18
1	1208	19
1	1208	20
1	1208	22
1	1208	24
1	1208	25
1	1209	3
1	1209	4
1	1209	5
1	1209	7
1	1209	8
1	1209	9
1	1209	10
1	1209	11
1	1209	14
1	1209	15
1	1209	16
1	1209	18
1	1209	19
1	1209	20
1	1209	24
1	1210	1
1	1210	2
1	1210	4
1	1210	8
1	1210	10
1	1210	11
1	1210	13
1	1210	15
1	1210	16
1	1210	18
1	1210	19
1	1210	20
1	1210	21
1	1210	22
1	1210	25
1	1211	1
1	1211	2
1	1211	3
1	1211	5
1	1211	7
1	1211	10
1	1211	11
1	1211	12
1	1211	13
1	1211	15
1	1211	16
1	1211	17
1	1211	20
1	1211	23
1	1211	24
1	1212	1
1	1212	2
1	1212	3
1	1212	5
1	1212	6
1	1212	7
1	1212	8
1	1212	9
1	1212	10
1	1212	15
1	1212	16
1	1212	17
1	1212	18
1	1212	20
1	1212	24
1	1213	2
1	1213	3
1	1213	5
1	1213	6
1	1213	7
1	1213	8
1	1213	9
1	1213	10
1	1213	14
1	1213	17
1	1213	18
1	1213	20
1	1213	23
1	1213	24
1	1213	25
1	1214	1
1	1214	2
1	1214	3
1	1214	4
1	1214	5
1	1214	7
1	1214	8
1	1214	9
1	1214	13
1	1214	14
1	1214	18
1	1214	19
1	1214	20
1	1214	21
1	1214	23
1	1215	3
1	1215	7
1	1215	9
1	1215	11
1	1215	12
1	1215	13
1	1215	14
1	1215	15
1	1215	16
1	1215	17
1	1215	18
1	1215	20
1	1215	21
1	1215	22
1	1215	24
1	1216	1
1	1216	2
1	1216	3
1	1216	7
1	1216	10
1	1216	12
1	1216	14
1	1216	15
1	1216	17
1	1216	18
1	1216	20
1	1216	21
1	1216	22
1	1216	23
1	1216	24
1	1217	1
1	1217	3
1	1217	6
1	1217	7
1	1217	8
1	1217	9
1	1217	10
1	1217	11
1	1217	12
1	1217	13
1	1217	17
1	1217	19
1	1217	20
1	1217	24
1	1217	25
1	1218	1
1	1218	2
1	1218	3
1	1218	4
1	1218	5
1	1218	7
1	1218	9
1	1218	10
1	1218	11
1	1218	13
1	1218	14
1	1218	18
1	1218	20
1	1218	21
1	1218	23
1	1219	2
1	1219	3
1	1219	4
1	1219	5
1	1219	6
1	1219	8
1	1219	9
1	1219	10
1	1219	14
1	1219	16
1	1219	19
1	1219	20
1	1219	22
1	1219	23
1	1219	25
1	1220	2
1	1220	3
1	1220	4
1	1220	5
1	1220	6
1	1220	7
1	1220	9
1	1220	13
1	1220	14
1	1220	17
1	1220	18
1	1220	19
1	1220	20
1	1220	23
1	1220	25
1	1221	2
1	1221	3
1	1221	4
1	1221	6
1	1221	9
1	1221	10
1	1221	12
1	1221	14
1	1221	15
1	1221	18
1	1221	19
1	1221	21
1	1221	22
1	1221	23
1	1221	24
1	1222	1
1	1222	2
1	1222	3
1	1222	4
1	1222	5
1	1222	8
1	1222	9
1	1222	10
1	1222	11
1	1222	13
1	1222	15
1	1222	17
1	1222	20
1	1222	22
1	1222	24
1	1223	2
1	1223	6
1	1223	7
1	1223	8
1	1223	9
1	1223	10
1	1223	13
1	1223	14
1	1223	16
1	1223	17
1	1223	18
1	1223	20
1	1223	21
1	1223	22
1	1223	23
1	1224	1
1	1224	2
1	1224	4
1	1224	5
1	1224	6
1	1224	8
1	1224	9
1	1224	11
1	1224	12
1	1224	14
1	1224	15
1	1224	16
1	1224	17
1	1224	18
1	1224	19
1	1225	2
1	1225	3
1	1225	5
1	1225	7
1	1225	11
1	1225	13
1	1225	14
1	1225	15
1	1225	17
1	1225	18
1	1225	20
1	1225	21
1	1225	23
1	1225	24
1	1225	25
1	1226	1
1	1226	3
1	1226	5
1	1226	7
1	1226	8
1	1226	10
1	1226	11
1	1226	14
1	1226	15
1	1226	17
1	1226	19
1	1226	21
1	1226	22
1	1226	23
1	1226	24
1	1227	1
1	1227	2
1	1227	7
1	1227	8
1	1227	9
1	1227	10
1	1227	11
1	1227	12
1	1227	13
1	1227	14
1	1227	17
1	1227	19
1	1227	21
1	1227	22
1	1227	25
1	1228	1
1	1228	2
1	1228	3
1	1228	4
1	1228	6
1	1228	7
1	1228	9
1	1228	10
1	1228	12
1	1228	13
1	1228	17
1	1228	20
1	1228	22
1	1228	23
1	1228	24
1	1229	1
1	1229	2
1	1229	3
1	1229	5
1	1229	6
1	1229	7
1	1229	8
1	1229	13
1	1229	14
1	1229	17
1	1229	19
1	1229	20
1	1229	22
1	1229	24
1	1229	25
1	1230	1
1	1230	2
1	1230	3
1	1230	5
1	1230	6
1	1230	7
1	1230	8
1	1230	10
1	1230	11
1	1230	12
1	1230	13
1	1230	17
1	1230	18
1	1230	19
1	1230	21
1	1231	1
1	1231	3
1	1231	4
1	1231	5
1	1231	7
1	1231	8
1	1231	12
1	1231	13
1	1231	15
1	1231	16
1	1231	18
1	1231	20
1	1231	21
1	1231	22
1	1231	25
1	1232	2
1	1232	3
1	1232	5
1	1232	6
1	1232	9
1	1232	10
1	1232	13
1	1232	14
1	1232	15
1	1232	16
1	1232	19
1	1232	21
1	1232	23
1	1232	24
1	1232	25
1	1233	1
1	1233	4
1	1233	5
1	1233	9
1	1233	10
1	1233	13
1	1233	14
1	1233	15
1	1233	16
1	1233	17
1	1233	18
1	1233	19
1	1233	22
1	1233	23
1	1233	25
1	1234	1
1	1234	2
1	1234	5
1	1234	8
1	1234	9
1	1234	10
1	1234	14
1	1234	16
1	1234	17
1	1234	18
1	1234	19
1	1234	20
1	1234	21
1	1234	24
1	1234	25
1	1235	1
1	1235	2
1	1235	3
1	1235	4
1	1235	6
1	1235	9
1	1235	10
1	1235	11
1	1235	12
1	1235	13
1	1235	15
1	1235	17
1	1235	18
1	1235	20
1	1235	24
1	1236	1
1	1236	2
1	1236	3
1	1236	5
1	1236	6
1	1236	7
1	1236	9
1	1236	10
1	1236	11
1	1236	12
1	1236	13
1	1236	17
1	1236	19
1	1236	23
1	1236	25
1	1237	3
1	1237	5
1	1237	6
1	1237	7
1	1237	8
1	1237	9
1	1237	10
1	1237	12
1	1237	13
1	1237	14
1	1237	18
1	1237	21
1	1237	22
1	1237	24
1	1237	25
1	1238	2
1	1238	3
1	1238	5
1	1238	7
1	1238	8
1	1238	9
1	1238	11
1	1238	13
1	1238	14
1	1238	15
1	1238	16
1	1238	17
1	1238	18
1	1238	21
1	1238	25
1	1239	5
1	1239	6
1	1239	8
1	1239	9
1	1239	10
1	1239	11
1	1239	12
1	1239	13
1	1239	14
1	1239	15
1	1239	16
1	1239	18
1	1239	20
1	1239	22
1	1239	24
1	1240	1
1	1240	2
1	1240	3
1	1240	4
1	1240	5
1	1240	6
1	1240	9
1	1240	12
1	1240	13
1	1240	16
1	1240	18
1	1240	19
1	1240	20
1	1240	22
1	1240	24
1	1241	1
1	1241	4
1	1241	5
1	1241	8
1	1241	9
1	1241	10
1	1241	11
1	1241	12
1	1241	13
1	1241	15
1	1241	17
1	1241	20
1	1241	22
1	1241	24
1	1241	25
1	1242	1
1	1242	2
1	1242	4
1	1242	5
1	1242	7
1	1242	11
1	1242	14
1	1242	15
1	1242	16
1	1242	19
1	1242	20
1	1242	21
1	1242	23
1	1242	24
1	1242	25
1	1243	1
1	1243	2
1	1243	4
1	1243	5
1	1243	6
1	1243	8
1	1243	12
1	1243	13
1	1243	14
1	1243	15
1	1243	16
1	1243	17
1	1243	22
1	1243	24
1	1243	25
1	1244	1
1	1244	3
1	1244	5
1	1244	7
1	1244	9
1	1244	10
1	1244	11
1	1244	12
1	1244	13
1	1244	16
1	1244	17
1	1244	19
1	1244	21
1	1244	23
1	1244	25
1	1245	2
1	1245	3
1	1245	4
1	1245	5
1	1245	6
1	1245	8
1	1245	9
1	1245	11
1	1245	15
1	1245	16
1	1245	17
1	1245	18
1	1245	19
1	1245	21
1	1245	25
1	1246	1
1	1246	4
1	1246	7
1	1246	8
1	1246	9
1	1246	10
1	1246	12
1	1246	13
1	1246	16
1	1246	17
1	1246	18
1	1246	19
1	1246	22
1	1246	24
1	1246	25
1	1247	2
1	1247	3
1	1247	7
1	1247	8
1	1247	9
1	1247	11
1	1247	15
1	1247	16
1	1247	17
1	1247	18
1	1247	19
1	1247	20
1	1247	23
1	1247	24
1	1247	25
1	1248	1
1	1248	3
1	1248	5
1	1248	10
1	1248	11
1	1248	12
1	1248	13
1	1248	15
1	1248	16
1	1248	17
1	1248	19
1	1248	20
1	1248	22
1	1248	24
1	1248	25
1	1249	3
1	1249	4
1	1249	5
1	1249	6
1	1249	9
1	1249	12
1	1249	13
1	1249	14
1	1249	15
1	1249	18
1	1249	19
1	1249	20
1	1249	22
1	1249	24
1	1249	25
1	1250	2
1	1250	3
1	1250	4
1	1250	5
1	1250	7
1	1250	9
1	1250	10
1	1250	14
1	1250	15
1	1250	17
1	1250	18
1	1250	19
1	1250	20
1	1250	24
1	1250	25
1	1251	2
1	1251	6
1	1251	7
1	1251	8
1	1251	9
1	1251	10
1	1251	14
1	1251	15
1	1251	16
1	1251	17
1	1251	19
1	1251	20
1	1251	21
1	1251	23
1	1251	25
1	1252	1
1	1252	3
1	1252	4
1	1252	5
1	1252	6
1	1252	8
1	1252	9
1	1252	10
1	1252	11
1	1252	12
1	1252	15
1	1252	20
1	1252	21
1	1252	23
1	1252	24
1	1253	1
1	1253	2
1	1253	3
1	1253	5
1	1253	6
1	1253	7
1	1253	11
1	1253	15
1	1253	16
1	1253	18
1	1253	20
1	1253	22
1	1253	23
1	1253	24
1	1253	25
1	1254	2
1	1254	3
1	1254	8
1	1254	9
1	1254	11
1	1254	12
1	1254	14
1	1254	15
1	1254	16
1	1254	17
1	1254	18
1	1254	20
1	1254	21
1	1254	22
1	1254	23
1	1255	1
1	1255	2
1	1255	4
1	1255	6
1	1255	7
1	1255	9
1	1255	10
1	1255	13
1	1255	14
1	1255	16
1	1255	18
1	1255	20
1	1255	21
1	1255	23
1	1255	25
1	1256	1
1	1256	2
1	1256	6
1	1256	8
1	1256	10
1	1256	11
1	1256	12
1	1256	13
1	1256	14
1	1256	15
1	1256	16
1	1256	18
1	1256	19
1	1256	22
1	1256	23
1	1257	1
1	1257	2
1	1257	5
1	1257	6
1	1257	8
1	1257	10
1	1257	11
1	1257	12
1	1257	13
1	1257	14
1	1257	16
1	1257	19
1	1257	20
1	1257	22
1	1257	25
1	1258	2
1	1258	3
1	1258	4
1	1258	5
1	1258	6
1	1258	8
1	1258	9
1	1258	10
1	1258	12
1	1258	13
1	1258	14
1	1258	20
1	1258	21
1	1258	23
1	1258	25
1	1259	2
1	1259	5
1	1259	8
1	1259	9
1	1259	10
1	1259	13
1	1259	14
1	1259	16
1	1259	17
1	1259	18
1	1259	19
1	1259	20
1	1259	22
1	1259	23
1	1259	25
1	1260	1
1	1260	2
1	1260	3
1	1260	4
1	1260	5
1	1260	6
1	1260	7
1	1260	11
1	1260	14
1	1260	15
1	1260	17
1	1260	18
1	1260	20
1	1260	22
1	1260	24
1	1261	1
1	1261	4
1	1261	5
1	1261	7
1	1261	10
1	1261	12
1	1261	15
1	1261	16
1	1261	17
1	1261	18
1	1261	19
1	1261	20
1	1261	21
1	1261	22
1	1261	25
1	1262	1
1	1262	3
1	1262	4
1	1262	6
1	1262	8
1	1262	11
1	1262	12
1	1262	13
1	1262	16
1	1262	17
1	1262	20
1	1262	21
1	1262	22
1	1262	23
1	1262	24
1	1263	3
1	1263	4
1	1263	5
1	1263	8
1	1263	9
1	1263	10
1	1263	11
1	1263	12
1	1263	13
1	1263	16
1	1263	18
1	1263	20
1	1263	22
1	1263	23
1	1263	25
1	1264	1
1	1264	4
1	1264	5
1	1264	8
1	1264	10
1	1264	11
1	1264	12
1	1264	14
1	1264	17
1	1264	18
1	1264	21
1	1264	22
1	1264	23
1	1264	24
1	1264	25
1	1265	1
1	1265	2
1	1265	3
1	1265	4
1	1265	7
1	1265	11
1	1265	13
1	1265	14
1	1265	15
1	1265	16
1	1265	19
1	1265	22
1	1265	23
1	1265	24
1	1265	25
1	1266	1
1	1266	2
1	1266	3
1	1266	5
1	1266	6
1	1266	8
1	1266	9
1	1266	10
1	1266	11
1	1266	13
1	1266	14
1	1266	15
1	1266	20
1	1266	23
1	1266	24
1	1267	2
1	1267	3
1	1267	5
1	1267	6
1	1267	7
1	1267	9
1	1267	11
1	1267	12
1	1267	13
1	1267	15
1	1267	16
1	1267	17
1	1267	18
1	1267	22
1	1267	25
1	1268	1
1	1268	2
1	1268	3
1	1268	6
1	1268	7
1	1268	8
1	1268	11
1	1268	12
1	1268	13
1	1268	15
1	1268	17
1	1268	18
1	1268	21
1	1268	22
1	1268	24
1	1269	1
1	1269	4
1	1269	5
1	1269	7
1	1269	8
1	1269	11
1	1269	13
1	1269	14
1	1269	16
1	1269	17
1	1269	18
1	1269	20
1	1269	21
1	1269	22
1	1269	23
1	1270	1
1	1270	2
1	1270	3
1	1270	4
1	1270	5
1	1270	6
1	1270	8
1	1270	9
1	1270	10
1	1270	11
1	1270	13
1	1270	20
1	1270	21
1	1270	23
1	1270	25
1	1271	1
1	1271	2
1	1271	4
1	1271	6
1	1271	8
1	1271	9
1	1271	11
1	1271	12
1	1271	13
1	1271	14
1	1271	17
1	1271	18
1	1271	23
1	1271	24
1	1271	25
1	1272	1
1	1272	4
1	1272	7
1	1272	9
1	1272	10
1	1272	14
1	1272	15
1	1272	17
1	1272	18
1	1272	19
1	1272	20
1	1272	21
1	1272	23
1	1272	24
1	1272	25
1	1273	1
1	1273	3
1	1273	5
1	1273	6
1	1273	8
1	1273	11
1	1273	12
1	1273	13
1	1273	14
1	1273	15
1	1273	18
1	1273	19
1	1273	20
1	1273	22
1	1273	24
1	1274	1
1	1274	3
1	1274	7
1	1274	8
1	1274	10
1	1274	11
1	1274	12
1	1274	13
1	1274	14
1	1274	15
1	1274	18
1	1274	19
1	1274	20
1	1274	22
1	1274	25
1	1275	3
1	1275	6
1	1275	7
1	1275	8
1	1275	10
1	1275	11
1	1275	13
1	1275	14
1	1275	15
1	1275	16
1	1275	17
1	1275	18
1	1275	20
1	1275	23
1	1275	25
1	1276	1
1	1276	3
1	1276	5
1	1276	7
1	1276	10
1	1276	12
1	1276	14
1	1276	15
1	1276	16
1	1276	18
1	1276	19
1	1276	21
1	1276	22
1	1276	23
1	1276	24
1	1277	1
1	1277	2
1	1277	3
1	1277	4
1	1277	6
1	1277	9
1	1277	10
1	1277	12
1	1277	13
1	1277	15
1	1277	17
1	1277	18
1	1277	21
1	1277	22
1	1277	25
1	1278	4
1	1278	6
1	1278	7
1	1278	9
1	1278	10
1	1278	12
1	1278	15
1	1278	16
1	1278	17
1	1278	18
1	1278	19
1	1278	20
1	1278	21
1	1278	22
1	1278	24
1	1279	1
1	1279	3
1	1279	4
1	1279	7
1	1279	8
1	1279	9
1	1279	11
1	1279	12
1	1279	13
1	1279	14
1	1279	16
1	1279	18
1	1279	19
1	1279	21
1	1279	23
1	1280	1
1	1280	3
1	1280	4
1	1280	5
1	1280	7
1	1280	9
1	1280	11
1	1280	14
1	1280	15
1	1280	17
1	1280	19
1	1280	22
1	1280	23
1	1280	24
1	1280	25
1	1281	1
1	1281	3
1	1281	5
1	1281	6
1	1281	8
1	1281	9
1	1281	12
1	1281	13
1	1281	15
1	1281	19
1	1281	21
1	1281	22
1	1281	23
1	1281	24
1	1281	25
1	1282	5
1	1282	6
1	1282	7
1	1282	9
1	1282	10
1	1282	11
1	1282	12
1	1282	14
1	1282	17
1	1282	19
1	1282	20
1	1282	21
1	1282	22
1	1282	23
1	1282	25
1	1283	2
1	1283	6
1	1283	7
1	1283	8
1	1283	9
1	1283	10
1	1283	11
1	1283	12
1	1283	13
1	1283	15
1	1283	16
1	1283	17
1	1283	18
1	1283	22
1	1283	23
1	1284	2
1	1284	4
1	1284	5
1	1284	7
1	1284	8
1	1284	10
1	1284	11
1	1284	13
1	1284	16
1	1284	17
1	1284	18
1	1284	20
1	1284	22
1	1284	23
1	1284	25
1	1285	1
1	1285	2
1	1285	6
1	1285	7
1	1285	10
1	1285	11
1	1285	12
1	1285	15
1	1285	16
1	1285	17
1	1285	18
1	1285	20
1	1285	22
1	1285	24
1	1285	25
1	1286	1
1	1286	3
1	1286	4
1	1286	5
1	1286	7
1	1286	10
1	1286	11
1	1286	12
1	1286	16
1	1286	17
1	1286	19
1	1286	20
1	1286	21
1	1286	23
1	1286	25
1	1287	3
1	1287	4
1	1287	5
1	1287	6
1	1287	9
1	1287	11
1	1287	13
1	1287	17
1	1287	18
1	1287	19
1	1287	21
1	1287	22
1	1287	23
1	1287	24
1	1287	25
1	1288	1
1	1288	2
1	1288	5
1	1288	9
1	1288	10
1	1288	13
1	1288	15
1	1288	16
1	1288	17
1	1288	18
1	1288	19
1	1288	20
1	1288	23
1	1288	24
1	1288	25
1	1289	1
1	1289	2
1	1289	5
1	1289	7
1	1289	8
1	1289	11
1	1289	13
1	1289	15
1	1289	16
1	1289	17
1	1289	18
1	1289	20
1	1289	22
1	1289	24
1	1289	25
1	1290	1
1	1290	3
1	1290	4
1	1290	5
1	1290	6
1	1290	11
1	1290	13
1	1290	14
1	1290	16
1	1290	19
1	1290	20
1	1290	21
1	1290	22
1	1290	23
1	1290	25
1	1291	1
1	1291	6
1	1291	7
1	1291	8
1	1291	10
1	1291	11
1	1291	12
1	1291	13
1	1291	15
1	1291	16
1	1291	18
1	1291	19
1	1291	20
1	1291	21
1	1291	24
1	1292	1
1	1292	2
1	1292	3
1	1292	7
1	1292	8
1	1292	10
1	1292	11
1	1292	14
1	1292	15
1	1292	17
1	1292	19
1	1292	22
1	1292	23
1	1292	24
1	1292	25
1	1293	1
1	1293	2
1	1293	7
1	1293	8
1	1293	9
1	1293	10
1	1293	11
1	1293	12
1	1293	13
1	1293	15
1	1293	17
1	1293	18
1	1293	20
1	1293	22
1	1293	24
1	1294	2
1	1294	5
1	1294	6
1	1294	7
1	1294	8
1	1294	10
1	1294	11
1	1294	12
1	1294	13
1	1294	14
1	1294	16
1	1294	18
1	1294	20
1	1294	23
1	1294	25
1	1295	3
1	1295	6
1	1295	9
1	1295	10
1	1295	11
1	1295	12
1	1295	13
1	1295	14
1	1295	15
1	1295	17
1	1295	18
1	1295	19
1	1295	23
1	1295	24
1	1295	25
1	1296	5
1	1296	7
1	1296	9
1	1296	10
1	1296	11
1	1296	14
1	1296	15
1	1296	16
1	1296	17
1	1296	18
1	1296	19
1	1296	20
1	1296	21
1	1296	23
1	1296	25
1	1297	1
1	1297	2
1	1297	5
1	1297	6
1	1297	7
1	1297	8
1	1297	9
1	1297	10
1	1297	11
1	1297	12
1	1297	16
1	1297	17
1	1297	18
1	1297	19
1	1297	22
1	1298	2
1	1298	3
1	1298	4
1	1298	6
1	1298	7
1	1298	9
1	1298	12
1	1298	17
1	1298	18
1	1298	20
1	1298	21
1	1298	22
1	1298	23
1	1298	24
1	1298	25
1	1299	1
1	1299	3
1	1299	5
1	1299	7
1	1299	8
1	1299	11
1	1299	13
1	1299	17
1	1299	18
1	1299	19
1	1299	20
1	1299	21
1	1299	22
1	1299	23
1	1299	25
1	1300	2
1	1300	6
1	1300	7
1	1300	9
1	1300	10
1	1300	11
1	1300	12
1	1300	13
1	1300	14
1	1300	15
1	1300	18
1	1300	20
1	1300	23
1	1300	24
1	1300	25
1	1301	1
1	1301	2
1	1301	3
1	1301	4
1	1301	6
1	1301	7
1	1301	9
1	1301	10
1	1301	14
1	1301	16
1	1301	17
1	1301	19
1	1301	22
1	1301	24
1	1301	25
1	1302	3
1	1302	4
1	1302	6
1	1302	9
1	1302	11
1	1302	12
1	1302	13
1	1302	14
1	1302	15
1	1302	16
1	1302	17
1	1302	18
1	1302	20
1	1302	22
1	1302	25
1	1303	1
1	1303	5
1	1303	8
1	1303	9
1	1303	10
1	1303	11
1	1303	13
1	1303	14
1	1303	15
1	1303	16
1	1303	18
1	1303	19
1	1303	20
1	1303	22
1	1303	23
1	1304	1
1	1304	2
1	1304	3
1	1304	7
1	1304	8
1	1304	10
1	1304	11
1	1304	13
1	1304	14
1	1304	17
1	1304	18
1	1304	19
1	1304	20
1	1304	21
1	1304	25
1	1305	2
1	1305	3
1	1305	4
1	1305	5
1	1305	6
1	1305	7
1	1305	8
1	1305	11
1	1305	12
1	1305	13
1	1305	15
1	1305	17
1	1305	20
1	1305	23
1	1305	25
1	1306	1
1	1306	2
1	1306	5
1	1306	6
1	1306	7
1	1306	9
1	1306	12
1	1306	13
1	1306	14
1	1306	15
1	1306	18
1	1306	19
1	1306	20
1	1306	22
1	1306	23
1	1307	3
1	1307	4
1	1307	6
1	1307	8
1	1307	9
1	1307	10
1	1307	12
1	1307	13
1	1307	14
1	1307	15
1	1307	16
1	1307	18
1	1307	20
1	1307	21
1	1307	23
1	1308	3
1	1308	5
1	1308	6
1	1308	7
1	1308	8
1	1308	9
1	1308	11
1	1308	14
1	1308	16
1	1308	17
1	1308	19
1	1308	20
1	1308	22
1	1308	23
1	1308	25
1	1309	2
1	1309	4
1	1309	5
1	1309	6
1	1309	8
1	1309	10
1	1309	12
1	1309	13
1	1309	14
1	1309	16
1	1309	18
1	1309	19
1	1309	20
1	1309	24
1	1309	25
1	1310	1
1	1310	2
1	1310	3
1	1310	4
1	1310	5
1	1310	7
1	1310	8
1	1310	10
1	1310	11
1	1310	15
1	1310	17
1	1310	18
1	1310	19
1	1310	21
1	1310	23
1	1311	2
1	1311	3
1	1311	5
1	1311	6
1	1311	8
1	1311	10
1	1311	11
1	1311	12
1	1311	14
1	1311	15
1	1311	17
1	1311	18
1	1311	20
1	1311	23
1	1311	25
1	1312	1
1	1312	2
1	1312	4
1	1312	5
1	1312	6
1	1312	7
1	1312	9
1	1312	11
1	1312	13
1	1312	18
1	1312	19
1	1312	20
1	1312	23
1	1312	24
1	1312	25
1	1313	1
1	1313	4
1	1313	8
1	1313	10
1	1313	11
1	1313	13
1	1313	15
1	1313	16
1	1313	17
1	1313	20
1	1313	21
1	1313	22
1	1313	23
1	1313	24
1	1313	25
1	1314	3
1	1314	5
1	1314	8
1	1314	9
1	1314	10
1	1314	11
1	1314	14
1	1314	15
1	1314	16
1	1314	18
1	1314	19
1	1314	21
1	1314	22
1	1314	24
1	1314	25
1	1315	1
1	1315	2
1	1315	3
1	1315	4
1	1315	5
1	1315	8
1	1315	10
1	1315	11
1	1315	12
1	1315	14
1	1315	16
1	1315	18
1	1315	19
1	1315	23
1	1315	25
1	1316	1
1	1316	2
1	1316	3
1	1316	4
1	1316	5
1	1316	6
1	1316	11
1	1316	12
1	1316	15
1	1316	17
1	1316	19
1	1316	20
1	1316	23
1	1316	24
1	1316	25
1	1317	1
1	1317	3
1	1317	5
1	1317	7
1	1317	8
1	1317	9
1	1317	10
1	1317	11
1	1317	14
1	1317	16
1	1317	20
1	1317	22
1	1317	23
1	1317	24
1	1317	25
1	1318	1
1	1318	2
1	1318	3
1	1318	4
1	1318	6
1	1318	7
1	1318	8
1	1318	9
1	1318	12
1	1318	13
1	1318	14
1	1318	15
1	1318	17
1	1318	20
1	1318	23
1	1319	3
1	1319	5
1	1319	6
1	1319	8
1	1319	9
1	1319	10
1	1319	11
1	1319	13
1	1319	14
1	1319	15
1	1319	17
1	1319	19
1	1319	22
1	1319	23
1	1319	25
1	1320	2
1	1320	3
1	1320	4
1	1320	5
1	1320	9
1	1320	11
1	1320	12
1	1320	13
1	1320	15
1	1320	16
1	1320	17
1	1320	21
1	1320	22
1	1320	23
1	1320	25
1	1321	2
1	1321	3
1	1321	4
1	1321	6
1	1321	7
1	1321	9
1	1321	10
1	1321	11
1	1321	13
1	1321	14
1	1321	18
1	1321	19
1	1321	20
1	1321	23
1	1321	24
1	1322	1
1	1322	2
1	1322	6
1	1322	7
1	1322	8
1	1322	9
1	1322	11
1	1322	13
1	1322	15
1	1322	16
1	1322	17
1	1322	18
1	1322	21
1	1322	24
1	1322	25
1	1323	1
1	1323	4
1	1323	5
1	1323	6
1	1323	9
1	1323	10
1	1323	11
1	1323	13
1	1323	14
1	1323	17
1	1323	19
1	1323	20
1	1323	21
1	1323	22
1	1323	23
1	1324	1
1	1324	4
1	1324	5
1	1324	6
1	1324	7
1	1324	8
1	1324	10
1	1324	11
1	1324	13
1	1324	17
1	1324	18
1	1324	19
1	1324	21
1	1324	24
1	1324	25
1	1325	2
1	1325	3
1	1325	5
1	1325	6
1	1325	7
1	1325	9
1	1325	10
1	1325	14
1	1325	15
1	1325	16
1	1325	18
1	1325	19
1	1325	20
1	1325	21
1	1325	25
1	1326	1
1	1326	3
1	1326	4
1	1326	6
1	1326	8
1	1326	9
1	1326	10
1	1326	17
1	1326	18
1	1326	19
1	1326	20
1	1326	21
1	1326	22
1	1326	24
1	1326	25
1	1327	1
1	1327	3
1	1327	4
1	1327	5
1	1327	7
1	1327	10
1	1327	13
1	1327	14
1	1327	16
1	1327	17
1	1327	18
1	1327	20
1	1327	22
1	1327	23
1	1327	25
1	1328	2
1	1328	5
1	1328	6
1	1328	8
1	1328	9
1	1328	10
1	1328	13
1	1328	15
1	1328	16
1	1328	17
1	1328	21
1	1328	22
1	1328	23
1	1328	24
1	1328	25
1	1329	2
1	1329	3
1	1329	4
1	1329	5
1	1329	7
1	1329	10
1	1329	11
1	1329	13
1	1329	15
1	1329	16
1	1329	18
1	1329	22
1	1329	23
1	1329	24
1	1329	25
1	1330	4
1	1330	5
1	1330	7
1	1330	10
1	1330	12
1	1330	13
1	1330	16
1	1330	17
1	1330	18
1	1330	19
1	1330	20
1	1330	22
1	1330	23
1	1330	24
1	1330	25
1	1331	1
1	1331	2
1	1331	3
1	1331	5
1	1331	6
1	1331	7
1	1331	10
1	1331	11
1	1331	14
1	1331	15
1	1331	16
1	1331	18
1	1331	23
1	1331	24
1	1331	25
1	1332	1
1	1332	4
1	1332	5
1	1332	6
1	1332	8
1	1332	11
1	1332	12
1	1332	13
1	1332	14
1	1332	15
1	1332	16
1	1332	18
1	1332	20
1	1332	21
1	1332	24
1	1333	3
1	1333	4
1	1333	5
1	1333	7
1	1333	8
1	1333	9
1	1333	10
1	1333	11
1	1333	12
1	1333	14
1	1333	17
1	1333	18
1	1333	20
1	1333	22
1	1333	24
1	1334	3
1	1334	4
1	1334	6
1	1334	7
1	1334	9
1	1334	10
1	1334	11
1	1334	13
1	1334	15
1	1334	16
1	1334	17
1	1334	18
1	1334	19
1	1334	21
1	1334	22
1	1335	1
1	1335	3
1	1335	4
1	1335	6
1	1335	7
1	1335	9
1	1335	10
1	1335	11
1	1335	13
1	1335	16
1	1335	17
1	1335	18
1	1335	23
1	1335	24
1	1335	25
1	1336	6
1	1336	8
1	1336	9
1	1336	10
1	1336	11
1	1336	12
1	1336	13
1	1336	14
1	1336	15
1	1336	17
1	1336	18
1	1336	19
1	1336	20
1	1336	22
1	1336	24
1	1337	1
1	1337	3
1	1337	5
1	1337	6
1	1337	8
1	1337	9
1	1337	10
1	1337	12
1	1337	13
1	1337	15
1	1337	16
1	1337	19
1	1337	21
1	1337	23
1	1337	25
1	1338	1
1	1338	2
1	1338	3
1	1338	4
1	1338	6
1	1338	7
1	1338	10
1	1338	11
1	1338	12
1	1338	13
1	1338	14
1	1338	15
1	1338	16
1	1338	17
1	1338	19
1	1339	2
1	1339	3
1	1339	4
1	1339	5
1	1339	6
1	1339	7
1	1339	8
1	1339	11
1	1339	13
1	1339	14
1	1339	16
1	1339	20
1	1339	21
1	1339	23
1	1339	24
1	1340	1
1	1340	2
1	1340	4
1	1340	5
1	1340	7
1	1340	9
1	1340	10
1	1340	12
1	1340	13
1	1340	14
1	1340	16
1	1340	17
1	1340	18
1	1340	19
1	1340	22
1	1341	1
1	1341	3
1	1341	4
1	1341	8
1	1341	9
1	1341	10
1	1341	13
1	1341	14
1	1341	15
1	1341	16
1	1341	17
1	1341	20
1	1341	21
1	1341	23
1	1341	24
1	1342	1
1	1342	2
1	1342	3
1	1342	5
1	1342	9
1	1342	10
1	1342	11
1	1342	12
1	1342	13
1	1342	15
1	1342	20
1	1342	21
1	1342	23
1	1342	24
1	1342	25
1	1343	2
1	1343	4
1	1343	5
1	1343	9
1	1343	10
1	1343	11
1	1343	13
1	1343	14
1	1343	15
1	1343	16
1	1343	17
1	1343	19
1	1343	21
1	1343	23
1	1343	24
1	1344	2
1	1344	4
1	1344	6
1	1344	7
1	1344	8
1	1344	10
1	1344	11
1	1344	12
1	1344	13
1	1344	17
1	1344	18
1	1344	21
1	1344	23
1	1344	24
1	1344	25
1	1345	1
1	1345	3
1	1345	7
1	1345	8
1	1345	9
1	1345	10
1	1345	11
1	1345	14
1	1345	15
1	1345	17
1	1345	19
1	1345	21
1	1345	22
1	1345	24
1	1345	25
1	1346	2
1	1346	3
1	1346	5
1	1346	7
1	1346	8
1	1346	10
1	1346	11
1	1346	14
1	1346	15
1	1346	18
1	1346	19
1	1346	20
1	1346	21
1	1346	23
1	1346	25
1	1347	1
1	1347	3
1	1347	5
1	1347	6
1	1347	7
1	1347	8
1	1347	10
1	1347	12
1	1347	13
1	1347	14
1	1347	17
1	1347	18
1	1347	20
1	1347	23
1	1347	24
1	1348	1
1	1348	2
1	1348	6
1	1348	7
1	1348	8
1	1348	9
1	1348	10
1	1348	14
1	1348	15
1	1348	18
1	1348	20
1	1348	21
1	1348	22
1	1348	24
1	1348	25
1	1349	2
1	1349	3
1	1349	4
1	1349	5
1	1349	6
1	1349	7
1	1349	8
1	1349	12
1	1349	14
1	1349	16
1	1349	18
1	1349	19
1	1349	21
1	1349	24
1	1349	25
1	1350	1
1	1350	5
1	1350	6
1	1350	8
1	1350	9
1	1350	11
1	1350	12
1	1350	13
1	1350	14
1	1350	16
1	1350	18
1	1350	19
1	1350	20
1	1350	21
1	1350	23
1	1351	2
1	1351	4
1	1351	6
1	1351	7
1	1351	10
1	1351	11
1	1351	13
1	1351	17
1	1351	19
1	1351	20
1	1351	21
1	1351	22
1	1351	23
1	1351	24
1	1351	25
1	1352	6
1	1352	8
1	1352	10
1	1352	11
1	1352	12
1	1352	13
1	1352	14
1	1352	15
1	1352	16
1	1352	19
1	1352	20
1	1352	21
1	1352	23
1	1352	24
1	1352	25
1	1353	3
1	1353	5
1	1353	7
1	1353	8
1	1353	9
1	1353	10
1	1353	11
1	1353	12
1	1353	14
1	1353	18
1	1353	21
1	1353	22
1	1353	23
1	1353	24
1	1353	25
1	1354	1
1	1354	2
1	1354	3
1	1354	5
1	1354	7
1	1354	9
1	1354	11
1	1354	12
1	1354	13
1	1354	14
1	1354	15
1	1354	18
1	1354	20
1	1354	21
1	1354	24
1	1355	1
1	1355	2
1	1355	3
1	1355	4
1	1355	6
1	1355	7
1	1355	8
1	1355	11
1	1355	15
1	1355	16
1	1355	18
1	1355	20
1	1355	21
1	1355	22
1	1355	24
1	1356	3
1	1356	4
1	1356	6
1	1356	8
1	1356	9
1	1356	10
1	1356	11
1	1356	12
1	1356	13
1	1356	14
1	1356	15
1	1356	16
1	1356	17
1	1356	19
1	1356	20
1	1357	3
1	1357	7
1	1357	8
1	1357	9
1	1357	10
1	1357	11
1	1357	12
1	1357	13
1	1357	15
1	1357	17
1	1357	18
1	1357	20
1	1357	21
1	1357	22
1	1357	23
1	1358	1
1	1358	2
1	1358	3
1	1358	4
1	1358	6
1	1358	8
1	1358	9
1	1358	13
1	1358	15
1	1358	17
1	1358	18
1	1358	19
1	1358	20
1	1358	22
1	1358	23
1	1359	3
1	1359	5
1	1359	7
1	1359	8
1	1359	9
1	1359	11
1	1359	13
1	1359	14
1	1359	15
1	1359	16
1	1359	17
1	1359	18
1	1359	20
1	1359	21
1	1359	23
1	1360	1
1	1360	2
1	1360	3
1	1360	4
1	1360	5
1	1360	6
1	1360	8
1	1360	10
1	1360	11
1	1360	12
1	1360	14
1	1360	18
1	1360	20
1	1360	23
1	1360	24
1	1361	1
1	1361	4
1	1361	5
1	1361	11
1	1361	12
1	1361	13
1	1361	14
1	1361	15
1	1361	16
1	1361	17
1	1361	18
1	1361	19
1	1361	20
1	1361	23
1	1361	25
1	1362	1
1	1362	3
1	1362	4
1	1362	6
1	1362	9
1	1362	10
1	1362	11
1	1362	12
1	1362	13
1	1362	16
1	1362	21
1	1362	22
1	1362	23
1	1362	24
1	1362	25
1	1363	5
1	1363	7
1	1363	9
1	1363	10
1	1363	12
1	1363	13
1	1363	14
1	1363	15
1	1363	16
1	1363	17
1	1363	19
1	1363	20
1	1363	21
1	1363	22
1	1363	23
1	1364	1
1	1364	6
1	1364	9
1	1364	10
1	1364	11
1	1364	12
1	1364	13
1	1364	15
1	1364	16
1	1364	17
1	1364	18
1	1364	20
1	1364	22
1	1364	24
1	1364	25
1	1365	2
1	1365	3
1	1365	6
1	1365	9
1	1365	10
1	1365	12
1	1365	14
1	1365	15
1	1365	19
1	1365	20
1	1365	21
1	1365	22
1	1365	23
1	1365	24
1	1365	25
1	1366	4
1	1366	8
1	1366	9
1	1366	10
1	1366	11
1	1366	12
1	1366	13
1	1366	14
1	1366	15
1	1366	16
1	1366	17
1	1366	21
1	1366	22
1	1366	24
1	1366	25
1	1367	2
1	1367	3
1	1367	4
1	1367	5
1	1367	6
1	1367	7
1	1367	9
1	1367	14
1	1367	15
1	1367	16
1	1367	17
1	1367	18
1	1367	20
1	1367	23
1	1367	24
1	1368	5
1	1368	7
1	1368	8
1	1368	10
1	1368	11
1	1368	12
1	1368	14
1	1368	16
1	1368	18
1	1368	19
1	1368	20
1	1368	22
1	1368	23
1	1368	24
1	1368	25
1	1369	3
1	1369	4
1	1369	5
1	1369	9
1	1369	10
1	1369	11
1	1369	12
1	1369	13
1	1369	14
1	1369	16
1	1369	17
1	1369	18
1	1369	21
1	1369	22
1	1369	24
1	1370	2
1	1370	4
1	1370	5
1	1370	7
1	1370	8
1	1370	11
1	1370	13
1	1370	14
1	1370	17
1	1370	18
1	1370	20
1	1370	21
1	1370	22
1	1370	24
1	1370	25
1	1371	3
1	1371	4
1	1371	5
1	1371	7
1	1371	13
1	1371	15
1	1371	17
1	1371	18
1	1371	19
1	1371	20
1	1371	21
1	1371	22
1	1371	23
1	1371	24
1	1371	25
1	1372	1
1	1372	2
1	1372	3
1	1372	5
1	1372	7
1	1372	9
1	1372	10
1	1372	13
1	1372	15
1	1372	16
1	1372	17
1	1372	18
1	1372	21
1	1372	23
1	1372	25
1	1373	1
1	1373	2
1	1373	3
1	1373	4
1	1373	5
1	1373	6
1	1373	7
1	1373	8
1	1373	12
1	1373	17
1	1373	18
1	1373	20
1	1373	21
1	1373	23
1	1373	24
1	1374	2
1	1374	3
1	1374	4
1	1374	5
1	1374	6
1	1374	9
1	1374	10
1	1374	14
1	1374	15
1	1374	16
1	1374	19
1	1374	20
1	1374	21
1	1374	23
1	1374	25
1	1375	1
1	1375	5
1	1375	6
1	1375	9
1	1375	10
1	1375	11
1	1375	14
1	1375	15
1	1375	16
1	1375	18
1	1375	20
1	1375	22
1	1375	23
1	1375	24
1	1375	25
1	1376	1
1	1376	3
1	1376	4
1	1376	5
1	1376	6
1	1376	12
1	1376	13
1	1376	14
1	1376	15
1	1376	16
1	1376	18
1	1376	19
1	1376	20
1	1376	22
1	1376	24
1	1377	1
1	1377	5
1	1377	6
1	1377	8
1	1377	9
1	1377	10
1	1377	12
1	1377	13
1	1377	15
1	1377	17
1	1377	19
1	1377	20
1	1377	21
1	1377	22
1	1377	25
1	1378	1
1	1378	2
1	1378	3
1	1378	6
1	1378	8
1	1378	10
1	1378	12
1	1378	13
1	1378	17
1	1378	19
1	1378	20
1	1378	21
1	1378	23
1	1378	24
1	1378	25
1	1379	1
1	1379	2
1	1379	4
1	1379	5
1	1379	7
1	1379	8
1	1379	9
1	1379	10
1	1379	12
1	1379	14
1	1379	15
1	1379	17
1	1379	18
1	1379	21
1	1379	22
1	1380	3
1	1380	4
1	1380	5
1	1380	6
1	1380	8
1	1380	11
1	1380	12
1	1380	14
1	1380	15
1	1380	16
1	1380	17
1	1380	21
1	1380	22
1	1380	24
1	1380	25
1	1381	1
1	1381	4
1	1381	6
1	1381	8
1	1381	9
1	1381	10
1	1381	12
1	1381	13
1	1381	14
1	1381	16
1	1381	17
1	1381	18
1	1381	19
1	1381	21
1	1381	25
1	1382	1
1	1382	6
1	1382	10
1	1382	12
1	1382	13
1	1382	14
1	1382	15
1	1382	16
1	1382	17
1	1382	18
1	1382	19
1	1382	20
1	1382	21
1	1382	22
1	1382	24
1	1383	2
1	1383	6
1	1383	7
1	1383	8
1	1383	9
1	1383	13
1	1383	14
1	1383	15
1	1383	16
1	1383	17
1	1383	20
1	1383	21
1	1383	22
1	1383	24
1	1383	25
1	1384	3
1	1384	4
1	1384	6
1	1384	8
1	1384	9
1	1384	11
1	1384	12
1	1384	13
1	1384	15
1	1384	18
1	1384	19
1	1384	20
1	1384	22
1	1384	24
1	1384	25
1	1385	4
1	1385	5
1	1385	8
1	1385	9
1	1385	10
1	1385	11
1	1385	12
1	1385	13
1	1385	14
1	1385	15
1	1385	17
1	1385	18
1	1385	19
1	1385	20
1	1385	23
1	1386	1
1	1386	2
1	1386	3
1	1386	4
1	1386	7
1	1386	9
1	1386	13
1	1386	16
1	1386	17
1	1386	18
1	1386	19
1	1386	21
1	1386	22
1	1386	24
1	1386	25
1	1387	1
1	1387	3
1	1387	4
1	1387	5
1	1387	6
1	1387	7
1	1387	9
1	1387	11
1	1387	12
1	1387	13
1	1387	14
1	1387	15
1	1387	16
1	1387	18
1	1387	24
1	1388	1
1	1388	3
1	1388	5
1	1388	7
1	1388	8
1	1388	10
1	1388	11
1	1388	12
1	1388	15
1	1388	18
1	1388	19
1	1388	20
1	1388	21
1	1388	23
1	1388	25
1	1389	1
1	1389	2
1	1389	4
1	1389	5
1	1389	6
1	1389	8
1	1389	10
1	1389	12
1	1389	14
1	1389	15
1	1389	16
1	1389	17
1	1389	18
1	1389	20
1	1389	21
1	1390	3
1	1390	5
1	1390	6
1	1390	7
1	1390	8
1	1390	11
1	1390	13
1	1390	14
1	1390	15
1	1390	16
1	1390	17
1	1390	18
1	1390	20
1	1390	21
1	1390	23
1	1391	1
1	1391	3
1	1391	5
1	1391	6
1	1391	10
1	1391	11
1	1391	12
1	1391	15
1	1391	16
1	1391	17
1	1391	19
1	1391	20
1	1391	21
1	1391	24
1	1391	25
1	1392	1
1	1392	2
1	1392	3
1	1392	4
1	1392	8
1	1392	9
1	1392	14
1	1392	15
1	1392	16
1	1392	17
1	1392	18
1	1392	20
1	1392	21
1	1392	22
1	1392	25
1	1393	3
1	1393	4
1	1393	5
1	1393	7
1	1393	9
1	1393	10
1	1393	11
1	1393	12
1	1393	13
1	1393	14
1	1393	17
1	1393	18
1	1393	20
1	1393	22
1	1393	23
1	1394	3
1	1394	4
1	1394	5
1	1394	6
1	1394	9
1	1394	10
1	1394	11
1	1394	14
1	1394	15
1	1394	16
1	1394	18
1	1394	19
1	1394	21
1	1394	22
1	1394	23
1	1395	5
1	1395	6
1	1395	7
1	1395	8
1	1395	11
1	1395	12
1	1395	13
1	1395	14
1	1395	16
1	1395	17
1	1395	18
1	1395	19
1	1395	22
1	1395	23
1	1395	25
1	1396	3
1	1396	5
1	1396	6
1	1396	7
1	1396	10
1	1396	12
1	1396	13
1	1396	17
1	1396	18
1	1396	19
1	1396	20
1	1396	22
1	1396	23
1	1396	24
1	1396	25
1	1397	1
1	1397	3
1	1397	4
1	1397	5
1	1397	6
1	1397	8
1	1397	9
1	1397	11
1	1397	12
1	1397	13
1	1397	14
1	1397	18
1	1397	21
1	1397	22
1	1397	25
1	1398	1
1	1398	4
1	1398	5
1	1398	6
1	1398	7
1	1398	8
1	1398	11
1	1398	14
1	1398	15
1	1398	16
1	1398	19
1	1398	20
1	1398	21
1	1398	24
1	1398	25
1	1399	4
1	1399	5
1	1399	6
1	1399	8
1	1399	9
1	1399	12
1	1399	13
1	1399	14
1	1399	15
1	1399	17
1	1399	19
1	1399	21
1	1399	22
1	1399	24
1	1399	25
1	1400	1
1	1400	2
1	1400	3
1	1400	5
1	1400	6
1	1400	9
1	1400	10
1	1400	12
1	1400	16
1	1400	19
1	1400	21
1	1400	22
1	1400	23
1	1400	24
1	1400	25
1	1401	1
1	1401	3
1	1401	4
1	1401	5
1	1401	6
1	1401	7
1	1401	8
1	1401	14
1	1401	15
1	1401	18
1	1401	19
1	1401	21
1	1401	22
1	1401	24
1	1401	25
1	1402	2
1	1402	3
1	1402	4
1	1402	5
1	1402	8
1	1402	9
1	1402	11
1	1402	12
1	1402	14
1	1402	15
1	1402	16
1	1402	19
1	1402	20
1	1402	21
1	1402	23
1	1403	3
1	1403	4
1	1403	5
1	1403	8
1	1403	9
1	1403	10
1	1403	11
1	1403	12
1	1403	13
1	1403	15
1	1403	16
1	1403	17
1	1403	21
1	1403	23
1	1403	25
1	1404	1
1	1404	2
1	1404	3
1	1404	4
1	1404	8
1	1404	10
1	1404	11
1	1404	13
1	1404	15
1	1404	16
1	1404	18
1	1404	19
1	1404	21
1	1404	22
1	1404	25
1	1405	2
1	1405	3
1	1405	4
1	1405	7
1	1405	9
1	1405	10
1	1405	11
1	1405	14
1	1405	15
1	1405	16
1	1405	18
1	1405	19
1	1405	20
1	1405	23
1	1405	24
1	1406	2
1	1406	3
1	1406	4
1	1406	5
1	1406	6
1	1406	9
1	1406	11
1	1406	13
1	1406	15
1	1406	19
1	1406	20
1	1406	21
1	1406	22
1	1406	24
1	1406	25
1	1407	1
1	1407	2
1	1407	4
1	1407	5
1	1407	6
1	1407	7
1	1407	10
1	1407	12
1	1407	13
1	1407	20
1	1407	21
1	1407	22
1	1407	23
1	1407	24
1	1407	25
1	1408	1
1	1408	3
1	1408	5
1	1408	8
1	1408	10
1	1408	11
1	1408	12
1	1408	13
1	1408	14
1	1408	19
1	1408	21
1	1408	22
1	1408	23
1	1408	24
1	1408	25
1	1409	1
1	1409	2
1	1409	4
1	1409	6
1	1409	7
1	1409	8
1	1409	11
1	1409	12
1	1409	14
1	1409	16
1	1409	17
1	1409	19
1	1409	22
1	1409	24
1	1409	25
1	1410	2
1	1410	3
1	1410	4
1	1410	5
1	1410	6
1	1410	7
1	1410	9
1	1410	10
1	1410	14
1	1410	15
1	1410	16
1	1410	17
1	1410	20
1	1410	21
1	1410	23
1	1411	1
1	1411	5
1	1411	6
1	1411	7
1	1411	8
1	1411	9
1	1411	10
1	1411	12
1	1411	13
1	1411	14
1	1411	15
1	1411	16
1	1411	17
1	1411	21
1	1411	23
1	1412	5
1	1412	6
1	1412	7
1	1412	9
1	1412	11
1	1412	13
1	1412	15
1	1412	16
1	1412	18
1	1412	19
1	1412	21
1	1412	22
1	1412	23
1	1412	24
1	1412	25
1	1413	2
1	1413	3
1	1413	4
1	1413	5
1	1413	6
1	1413	7
1	1413	8
1	1413	9
1	1413	10
1	1413	13
1	1413	16
1	1413	17
1	1413	18
1	1413	21
1	1413	25
1	1414	2
1	1414	3
1	1414	4
1	1414	5
1	1414	7
1	1414	9
1	1414	10
1	1414	11
1	1414	13
1	1414	14
1	1414	16
1	1414	17
1	1414	20
1	1414	21
1	1414	23
1	1415	2
1	1415	4
1	1415	5
1	1415	6
1	1415	10
1	1415	12
1	1415	13
1	1415	15
1	1415	17
1	1415	18
1	1415	19
1	1415	22
1	1415	23
1	1415	24
1	1415	25
1	1416	3
1	1416	4
1	1416	5
1	1416	7
1	1416	8
1	1416	9
1	1416	10
1	1416	12
1	1416	14
1	1416	15
1	1416	17
1	1416	18
1	1416	19
1	1416	20
1	1416	24
1	1417	1
1	1417	2
1	1417	3
1	1417	4
1	1417	6
1	1417	7
1	1417	9
1	1417	11
1	1417	13
1	1417	14
1	1417	15
1	1417	18
1	1417	19
1	1417	22
1	1417	23
1	1418	2
1	1418	4
1	1418	6
1	1418	9
1	1418	10
1	1418	11
1	1418	13
1	1418	14
1	1418	15
1	1418	17
1	1418	18
1	1418	20
1	1418	21
1	1418	22
1	1418	23
1	1419	2
1	1419	3
1	1419	6
1	1419	7
1	1419	11
1	1419	12
1	1419	15
1	1419	16
1	1419	17
1	1419	18
1	1419	19
1	1419	20
1	1419	21
1	1419	23
1	1419	24
1	1420	1
1	1420	4
1	1420	6
1	1420	7
1	1420	8
1	1420	10
1	1420	13
1	1420	14
1	1420	15
1	1420	16
1	1420	17
1	1420	20
1	1420	22
1	1420	23
1	1420	25
1	1421	3
1	1421	5
1	1421	6
1	1421	7
1	1421	8
1	1421	9
1	1421	11
1	1421	12
1	1421	14
1	1421	17
1	1421	18
1	1421	19
1	1421	20
1	1421	23
1	1421	24
1	1422	1
1	1422	4
1	1422	5
1	1422	7
1	1422	10
1	1422	11
1	1422	13
1	1422	14
1	1422	15
1	1422	16
1	1422	17
1	1422	19
1	1422	22
1	1422	23
1	1422	24
1	1423	1
1	1423	2
1	1423	4
1	1423	5
1	1423	7
1	1423	8
1	1423	11
1	1423	12
1	1423	13
1	1423	14
1	1423	15
1	1423	16
1	1423	19
1	1423	22
1	1423	23
1	1424	2
1	1424	4
1	1424	5
1	1424	6
1	1424	8
1	1424	9
1	1424	10
1	1424	11
1	1424	13
1	1424	17
1	1424	18
1	1424	20
1	1424	21
1	1424	23
1	1424	25
1	1425	1
1	1425	3
1	1425	4
1	1425	5
1	1425	8
1	1425	9
1	1425	11
1	1425	12
1	1425	13
1	1425	14
1	1425	16
1	1425	19
1	1425	20
1	1425	21
1	1425	25
1	1426	2
1	1426	3
1	1426	4
1	1426	7
1	1426	8
1	1426	10
1	1426	12
1	1426	14
1	1426	15
1	1426	16
1	1426	18
1	1426	22
1	1426	23
1	1426	24
1	1426	25
1	1427	1
1	1427	2
1	1427	7
1	1427	10
1	1427	11
1	1427	12
1	1427	14
1	1427	15
1	1427	16
1	1427	17
1	1427	18
1	1427	19
1	1427	20
1	1427	22
1	1427	25
1	1428	2
1	1428	3
1	1428	4
1	1428	5
1	1428	6
1	1428	8
1	1428	9
1	1428	13
1	1428	17
1	1428	18
1	1428	19
1	1428	20
1	1428	21
1	1428	22
1	1428	25
1	1429	5
1	1429	7
1	1429	8
1	1429	9
1	1429	10
1	1429	12
1	1429	13
1	1429	14
1	1429	15
1	1429	16
1	1429	18
1	1429	19
1	1429	20
1	1429	21
1	1429	25
1	1430	1
1	1430	3
1	1430	4
1	1430	5
1	1430	7
1	1430	8
1	1430	9
1	1430	13
1	1430	15
1	1430	16
1	1430	20
1	1430	21
1	1430	22
1	1430	23
1	1430	25
1	1431	1
1	1431	2
1	1431	7
1	1431	8
1	1431	9
1	1431	10
1	1431	12
1	1431	14
1	1431	15
1	1431	16
1	1431	17
1	1431	19
1	1431	20
1	1431	23
1	1431	25
1	1432	1
1	1432	3
1	1432	4
1	1432	5
1	1432	10
1	1432	11
1	1432	12
1	1432	16
1	1432	17
1	1432	18
1	1432	20
1	1432	21
1	1432	23
1	1432	24
1	1432	25
1	1433	3
1	1433	6
1	1433	7
1	1433	9
1	1433	10
1	1433	12
1	1433	14
1	1433	15
1	1433	16
1	1433	18
1	1433	20
1	1433	22
1	1433	23
1	1433	24
1	1433	25
1	1434	3
1	1434	4
1	1434	5
1	1434	6
1	1434	7
1	1434	9
1	1434	10
1	1434	12
1	1434	13
1	1434	15
1	1434	18
1	1434	19
1	1434	22
1	1434	23
1	1434	24
1	1435	1
1	1435	2
1	1435	3
1	1435	4
1	1435	5
1	1435	6
1	1435	9
1	1435	10
1	1435	12
1	1435	16
1	1435	17
1	1435	19
1	1435	20
1	1435	21
1	1435	23
1	1436	1
1	1436	2
1	1436	3
1	1436	5
1	1436	6
1	1436	8
1	1436	11
1	1436	12
1	1436	15
1	1436	17
1	1436	18
1	1436	19
1	1436	22
1	1436	23
1	1436	24
1	1437	2
1	1437	4
1	1437	5
1	1437	6
1	1437	7
1	1437	8
1	1437	9
1	1437	11
1	1437	13
1	1437	14
1	1437	17
1	1437	19
1	1437	20
1	1437	23
1	1437	25
1	1438	1
1	1438	4
1	1438	7
1	1438	8
1	1438	9
1	1438	10
1	1438	11
1	1438	12
1	1438	14
1	1438	15
1	1438	17
1	1438	20
1	1438	21
1	1438	22
1	1438	24
1	1439	1
1	1439	2
1	1439	3
1	1439	5
1	1439	11
1	1439	12
1	1439	13
1	1439	14
1	1439	15
1	1439	16
1	1439	17
1	1439	18
1	1439	19
1	1439	22
1	1439	24
1	1440	2
1	1440	3
1	1440	8
1	1440	10
1	1440	12
1	1440	13
1	1440	14
1	1440	16
1	1440	17
1	1440	18
1	1440	20
1	1440	21
1	1440	22
1	1440	24
1	1440	25
1	1441	1
1	1441	3
1	1441	4
1	1441	5
1	1441	6
1	1441	7
1	1441	9
1	1441	10
1	1441	11
1	1441	13
1	1441	16
1	1441	19
1	1441	22
1	1441	23
1	1441	25
1	1442	1
1	1442	2
1	1442	3
1	1442	4
1	1442	7
1	1442	9
1	1442	11
1	1442	12
1	1442	13
1	1442	15
1	1442	16
1	1442	17
1	1442	19
1	1442	20
1	1442	21
1	1443	1
1	1443	2
1	1443	3
1	1443	5
1	1443	7
1	1443	8
1	1443	9
1	1443	10
1	1443	11
1	1443	12
1	1443	14
1	1443	15
1	1443	16
1	1443	17
1	1443	24
1	1444	1
1	1444	2
1	1444	4
1	1444	5
1	1444	6
1	1444	9
1	1444	10
1	1444	11
1	1444	14
1	1444	15
1	1444	17
1	1444	18
1	1444	20
1	1444	21
1	1444	24
1	1445	1
1	1445	4
1	1445	5
1	1445	6
1	1445	8
1	1445	10
1	1445	13
1	1445	15
1	1445	16
1	1445	17
1	1445	18
1	1445	20
1	1445	22
1	1445	23
1	1445	25
1	1446	1
1	1446	4
1	1446	6
1	1446	7
1	1446	8
1	1446	12
1	1446	13
1	1446	16
1	1446	17
1	1446	20
1	1446	21
1	1446	22
1	1446	23
1	1446	24
1	1446	25
1	1447	1
1	1447	3
1	1447	4
1	1447	5
1	1447	8
1	1447	11
1	1447	12
1	1447	13
1	1447	17
1	1447	18
1	1447	19
1	1447	21
1	1447	22
1	1447	24
1	1447	25
1	1448	1
1	1448	3
1	1448	4
1	1448	5
1	1448	6
1	1448	8
1	1448	12
1	1448	13
1	1448	16
1	1448	18
1	1448	19
1	1448	21
1	1448	22
1	1448	23
1	1448	24
1	1449	1
1	1449	3
1	1449	4
1	1449	5
1	1449	6
1	1449	7
1	1449	8
1	1449	9
1	1449	11
1	1449	15
1	1449	16
1	1449	20
1	1449	22
1	1449	23
1	1449	24
1	1450	1
1	1450	2
1	1450	4
1	1450	5
1	1450	8
1	1450	9
1	1450	10
1	1450	13
1	1450	14
1	1450	16
1	1450	17
1	1450	19
1	1450	20
1	1450	22
1	1450	24
1	1451	1
1	1451	2
1	1451	3
1	1451	5
1	1451	10
1	1451	12
1	1451	13
1	1451	14
1	1451	15
1	1451	19
1	1451	20
1	1451	21
1	1451	23
1	1451	24
1	1451	25
1	1452	2
1	1452	5
1	1452	7
1	1452	8
1	1452	10
1	1452	11
1	1452	13
1	1452	14
1	1452	15
1	1452	17
1	1452	20
1	1452	21
1	1452	23
1	1452	24
1	1452	25
1	1453	1
1	1453	2
1	1453	5
1	1453	8
1	1453	9
1	1453	10
1	1453	13
1	1453	14
1	1453	15
1	1453	16
1	1453	19
1	1453	21
1	1453	23
1	1453	24
1	1453	25
1	1454	1
1	1454	3
1	1454	4
1	1454	7
1	1454	10
1	1454	12
1	1454	13
1	1454	14
1	1454	18
1	1454	19
1	1454	20
1	1454	21
1	1454	22
1	1454	23
1	1454	25
1	1455	2
1	1455	5
1	1455	7
1	1455	8
1	1455	14
1	1455	15
1	1455	16
1	1455	17
1	1455	18
1	1455	19
1	1455	20
1	1455	21
1	1455	22
1	1455	23
1	1455	25
1	1456	1
1	1456	2
1	1456	6
1	1456	7
1	1456	8
1	1456	9
1	1456	12
1	1456	13
1	1456	14
1	1456	15
1	1456	19
1	1456	20
1	1456	21
1	1456	24
1	1456	25
1	1457	1
1	1457	2
1	1457	3
1	1457	4
1	1457	7
1	1457	8
1	1457	9
1	1457	10
1	1457	11
1	1457	13
1	1457	14
1	1457	15
1	1457	18
1	1457	23
1	1457	24
1	1458	1
1	1458	2
1	1458	3
1	1458	5
1	1458	7
1	1458	9
1	1458	11
1	1458	14
1	1458	17
1	1458	18
1	1458	19
1	1458	20
1	1458	22
1	1458	23
1	1458	24
1	1459	1
1	1459	4
1	1459	6
1	1459	9
1	1459	10
1	1459	12
1	1459	13
1	1459	14
1	1459	16
1	1459	17
1	1459	18
1	1459	19
1	1459	20
1	1459	24
1	1459	25
1	1460	1
1	1460	3
1	1460	5
1	1460	7
1	1460	11
1	1460	14
1	1460	15
1	1460	16
1	1460	17
1	1460	18
1	1460	19
1	1460	20
1	1460	21
1	1460	24
1	1460	25
1	1461	2
1	1461	4
1	1461	5
1	1461	6
1	1461	9
1	1461	10
1	1461	11
1	1461	15
1	1461	17
1	1461	18
1	1461	19
1	1461	21
1	1461	23
1	1461	24
1	1461	25
1	1462	1
1	1462	3
1	1462	4
1	1462	5
1	1462	7
1	1462	9
1	1462	12
1	1462	13
1	1462	14
1	1462	16
1	1462	17
1	1462	20
1	1462	21
1	1462	24
1	1462	25
1	1463	3
1	1463	4
1	1463	6
1	1463	7
1	1463	10
1	1463	11
1	1463	13
1	1463	14
1	1463	15
1	1463	17
1	1463	19
1	1463	20
1	1463	22
1	1463	23
1	1463	24
1	1464	1
1	1464	4
1	1464	9
1	1464	10
1	1464	11
1	1464	12
1	1464	13
1	1464	14
1	1464	15
1	1464	16
1	1464	17
1	1464	18
1	1464	22
1	1464	23
1	1464	24
1	1465	2
1	1465	5
1	1465	7
1	1465	8
1	1465	9
1	1465	10
1	1465	12
1	1465	14
1	1465	16
1	1465	19
1	1465	20
1	1465	21
1	1465	22
1	1465	23
1	1465	24
1	1466	2
1	1466	3
1	1466	4
1	1466	6
1	1466	10
1	1466	11
1	1466	12
1	1466	14
1	1466	19
1	1466	20
1	1466	21
1	1466	22
1	1466	23
1	1466	24
1	1466	25
1	1467	1
1	1467	4
1	1467	5
1	1467	6
1	1467	9
1	1467	10
1	1467	11
1	1467	12
1	1467	19
1	1467	20
1	1467	21
1	1467	22
1	1467	23
1	1467	24
1	1467	25
1	1468	2
1	1468	3
1	1468	5
1	1468	6
1	1468	8
1	1468	11
1	1468	12
1	1468	13
1	1468	14
1	1468	18
1	1468	19
1	1468	20
1	1468	21
1	1468	23
1	1468	24
1	1469	1
1	1469	2
1	1469	3
1	1469	5
1	1469	6
1	1469	7
1	1469	8
1	1469	9
1	1469	11
1	1469	13
1	1469	16
1	1469	17
1	1469	18
1	1469	19
1	1469	20
1	1470	2
1	1470	3
1	1470	7
1	1470	8
1	1470	11
1	1470	12
1	1470	13
1	1470	14
1	1470	15
1	1470	18
1	1470	20
1	1470	21
1	1470	22
1	1470	23
1	1470	24
1	1471	1
1	1471	2
1	1471	4
1	1471	6
1	1471	7
1	1471	8
1	1471	10
1	1471	11
1	1471	13
1	1471	15
1	1471	18
1	1471	20
1	1471	21
1	1471	22
1	1471	24
1	1472	2
1	1472	3
1	1472	4
1	1472	5
1	1472	7
1	1472	8
1	1472	10
1	1472	12
1	1472	13
1	1472	14
1	1472	18
1	1472	21
1	1472	22
1	1472	23
1	1472	24
1	1473	1
1	1473	4
1	1473	5
1	1473	7
1	1473	8
1	1473	9
1	1473	10
1	1473	12
1	1473	14
1	1473	16
1	1473	20
1	1473	22
1	1473	23
1	1473	24
1	1473	25
1	1474	1
1	1474	2
1	1474	5
1	1474	7
1	1474	8
1	1474	10
1	1474	11
1	1474	13
1	1474	14
1	1474	15
1	1474	18
1	1474	19
1	1474	20
1	1474	21
1	1474	25
1	1475	1
1	1475	2
1	1475	3
1	1475	5
1	1475	6
1	1475	9
1	1475	10
1	1475	12
1	1475	13
1	1475	15
1	1475	18
1	1475	20
1	1475	21
1	1475	24
1	1475	25
1	1476	2
1	1476	4
1	1476	5
1	1476	6
1	1476	7
1	1476	9
1	1476	10
1	1476	12
1	1476	13
1	1476	14
1	1476	16
1	1476	19
1	1476	21
1	1476	22
1	1476	25
1	1477	1
1	1477	2
1	1477	3
1	1477	4
1	1477	5
1	1477	6
1	1477	7
1	1477	10
1	1477	12
1	1477	15
1	1477	17
1	1477	18
1	1477	21
1	1477	22
1	1477	23
1	1478	2
1	1478	5
1	1478	6
1	1478	7
1	1478	10
1	1478	11
1	1478	12
1	1478	15
1	1478	16
1	1478	17
1	1478	18
1	1478	19
1	1478	21
1	1478	24
1	1478	25
1	1479	2
1	1479	3
1	1479	5
1	1479	6
1	1479	9
1	1479	11
1	1479	13
1	1479	14
1	1479	15
1	1479	16
1	1479	17
1	1479	18
1	1479	20
1	1479	22
1	1479	23
1	1480	1
1	1480	6
1	1480	7
1	1480	10
1	1480	11
1	1480	12
1	1480	13
1	1480	15
1	1480	16
1	1480	17
1	1480	19
1	1480	20
1	1480	21
1	1480	22
1	1480	25
1	1481	2
1	1481	3
1	1481	5
1	1481	7
1	1481	8
1	1481	9
1	1481	11
1	1481	17
1	1481	18
1	1481	19
1	1481	20
1	1481	21
1	1481	23
1	1481	24
1	1481	25
1	1482	1
1	1482	2
1	1482	4
1	1482	5
1	1482	7
1	1482	8
1	1482	9
1	1482	10
1	1482	11
1	1482	12
1	1482	14
1	1482	15
1	1482	19
1	1482	23
1	1482	24
1	1483	3
1	1483	4
1	1483	5
1	1483	6
1	1483	7
1	1483	9
1	1483	11
1	1483	13
1	1483	14
1	1483	15
1	1483	17
1	1483	20
1	1483	21
1	1483	22
1	1483	23
1	1484	1
1	1484	2
1	1484	3
1	1484	4
1	1484	6
1	1484	7
1	1484	9
1	1484	10
1	1484	12
1	1484	17
1	1484	18
1	1484	19
1	1484	21
1	1484	22
1	1484	25
1	1485	1
1	1485	2
1	1485	3
1	1485	5
1	1485	8
1	1485	9
1	1485	11
1	1485	13
1	1485	15
1	1485	17
1	1485	18
1	1485	19
1	1485	23
1	1485	24
1	1485	25
1	1486	2
1	1486	4
1	1486	5
1	1486	8
1	1486	9
1	1486	10
1	1486	12
1	1486	14
1	1486	18
1	1486	19
1	1486	20
1	1486	21
1	1486	22
1	1486	23
1	1486	25
1	1487	1
1	1487	2
1	1487	3
1	1487	4
1	1487	5
1	1487	6
1	1487	10
1	1487	11
1	1487	12
1	1487	15
1	1487	16
1	1487	19
1	1487	21
1	1487	22
1	1487	25
1	1488	1
1	1488	4
1	1488	5
1	1488	6
1	1488	10
1	1488	11
1	1488	12
1	1488	13
1	1488	16
1	1488	19
1	1488	20
1	1488	21
1	1488	23
1	1488	24
1	1488	25
1	1489	2
1	1489	4
1	1489	7
1	1489	8
1	1489	9
1	1489	10
1	1489	12
1	1489	13
1	1489	14
1	1489	15
1	1489	19
1	1489	20
1	1489	22
1	1489	23
1	1489	25
1	1490	1
1	1490	3
1	1490	4
1	1490	5
1	1490	7
1	1490	8
1	1490	9
1	1490	11
1	1490	13
1	1490	14
1	1490	15
1	1490	18
1	1490	19
1	1490	20
1	1490	22
1	1491	2
1	1491	4
1	1491	5
1	1491	6
1	1491	7
1	1491	9
1	1491	11
1	1491	13
1	1491	14
1	1491	19
1	1491	20
1	1491	22
1	1491	23
1	1491	24
1	1491	25
1	1492	2
1	1492	3
1	1492	4
1	1492	5
1	1492	7
1	1492	8
1	1492	10
1	1492	12
1	1492	15
1	1492	16
1	1492	17
1	1492	18
1	1492	19
1	1492	24
1	1492	25
1	1493	2
1	1493	5
1	1493	8
1	1493	10
1	1493	11
1	1493	13
1	1493	14
1	1493	15
1	1493	16
1	1493	19
1	1493	20
1	1493	21
1	1493	23
1	1493	24
1	1493	25
1	1494	1
1	1494	2
1	1494	3
1	1494	4
1	1494	9
1	1494	10
1	1494	11
1	1494	12
1	1494	13
1	1494	15
1	1494	17
1	1494	19
1	1494	20
1	1494	22
1	1494	25
1	1495	1
1	1495	2
1	1495	3
1	1495	4
1	1495	5
1	1495	8
1	1495	10
1	1495	12
1	1495	13
1	1495	14
1	1495	18
1	1495	22
1	1495	23
1	1495	24
1	1495	25
1	1496	2
1	1496	3
1	1496	6
1	1496	7
1	1496	9
1	1496	10
1	1496	11
1	1496	12
1	1496	13
1	1496	15
1	1496	17
1	1496	19
1	1496	20
1	1496	23
1	1496	25
1	1497	1
1	1497	2
1	1497	5
1	1497	7
1	1497	11
1	1497	12
1	1497	13
1	1497	14
1	1497	15
1	1497	16
1	1497	17
1	1497	18
1	1497	19
1	1497	22
1	1497	23
1	1498	4
1	1498	5
1	1498	7
1	1498	8
1	1498	10
1	1498	11
1	1498	14
1	1498	15
1	1498	16
1	1498	17
1	1498	18
1	1498	21
1	1498	23
1	1498	24
1	1498	25
1	1499	1
1	1499	2
1	1499	3
1	1499	4
1	1499	5
1	1499	7
1	1499	8
1	1499	12
1	1499	13
1	1499	14
1	1499	15
1	1499	18
1	1499	19
1	1499	23
1	1499	24
1	1500	1
1	1500	2
1	1500	3
1	1500	5
1	1500	7
1	1500	10
1	1500	11
1	1500	12
1	1500	13
1	1500	15
1	1500	17
1	1500	18
1	1500	19
1	1500	20
1	1500	22
1	1501	1
1	1501	6
1	1501	7
1	1501	8
1	1501	9
1	1501	10
1	1501	11
1	1501	13
1	1501	16
1	1501	17
1	1501	18
1	1501	21
1	1501	22
1	1501	24
1	1501	25
1	1502	1
1	1502	2
1	1502	3
1	1502	4
1	1502	5
1	1502	7
1	1502	11
1	1502	12
1	1502	13
1	1502	15
1	1502	17
1	1502	18
1	1502	20
1	1502	22
1	1502	24
1	1503	1
1	1503	2
1	1503	3
1	1503	7
1	1503	12
1	1503	15
1	1503	16
1	1503	17
1	1503	18
1	1503	20
1	1503	21
1	1503	22
1	1503	23
1	1503	24
1	1503	25
1	1504	1
1	1504	4
1	1504	5
1	1504	7
1	1504	8
1	1504	11
1	1504	12
1	1504	14
1	1504	17
1	1504	18
1	1504	19
1	1504	21
1	1504	23
1	1504	24
1	1504	25
1	1505	1
1	1505	2
1	1505	3
1	1505	6
1	1505	7
1	1505	11
1	1505	14
1	1505	16
1	1505	17
1	1505	18
1	1505	19
1	1505	20
1	1505	22
1	1505	24
1	1505	25
1	1506	3
1	1506	4
1	1506	5
1	1506	8
1	1506	9
1	1506	10
1	1506	13
1	1506	14
1	1506	17
1	1506	18
1	1506	19
1	1506	20
1	1506	21
1	1506	22
1	1506	24
1	1507	1
1	1507	2
1	1507	3
1	1507	4
1	1507	5
1	1507	8
1	1507	10
1	1507	11
1	1507	13
1	1507	14
1	1507	17
1	1507	19
1	1507	21
1	1507	23
1	1507	24
1	1508	1
1	1508	3
1	1508	7
1	1508	8
1	1508	9
1	1508	10
1	1508	11
1	1508	12
1	1508	14
1	1508	17
1	1508	19
1	1508	21
1	1508	22
1	1508	23
1	1508	24
1	1509	1
1	1509	2
1	1509	3
1	1509	6
1	1509	7
1	1509	8
1	1509	9
1	1509	13
1	1509	14
1	1509	15
1	1509	17
1	1509	18
1	1509	19
1	1509	22
1	1509	24
1	1510	1
1	1510	3
1	1510	4
1	1510	7
1	1510	8
1	1510	9
1	1510	10
1	1510	11
1	1510	12
1	1510	13
1	1510	15
1	1510	18
1	1510	19
1	1510	22
1	1510	24
1	1511	2
1	1511	4
1	1511	5
1	1511	8
1	1511	9
1	1511	10
1	1511	11
1	1511	12
1	1511	13
1	1511	15
1	1511	19
1	1511	20
1	1511	21
1	1511	23
1	1511	24
1	1512	2
1	1512	3
1	1512	4
1	1512	6
1	1512	10
1	1512	11
1	1512	12
1	1512	13
1	1512	15
1	1512	16
1	1512	17
1	1512	19
1	1512	21
1	1512	22
1	1512	24
1	1513	3
1	1513	4
1	1513	6
1	1513	7
1	1513	9
1	1513	10
1	1513	11
1	1513	12
1	1513	13
1	1513	14
1	1513	16
1	1513	18
1	1513	21
1	1513	22
1	1513	24
1	1514	3
1	1514	4
1	1514	5
1	1514	7
1	1514	8
1	1514	11
1	1514	12
1	1514	13
1	1514	15
1	1514	16
1	1514	17
1	1514	19
1	1514	20
1	1514	21
1	1514	24
1	1515	1
1	1515	2
1	1515	3
1	1515	5
1	1515	8
1	1515	9
1	1515	11
1	1515	12
1	1515	13
1	1515	16
1	1515	17
1	1515	18
1	1515	19
1	1515	20
1	1515	23
1	1516	1
1	1516	2
1	1516	6
1	1516	7
1	1516	10
1	1516	11
1	1516	12
1	1516	14
1	1516	16
1	1516	18
1	1516	19
1	1516	20
1	1516	22
1	1516	23
1	1516	24
1	1517	2
1	1517	3
1	1517	5
1	1517	8
1	1517	10
1	1517	11
1	1517	12
1	1517	14
1	1517	15
1	1517	18
1	1517	20
1	1517	21
1	1517	23
1	1517	24
1	1517	25
1	1518	2
1	1518	3
1	1518	4
1	1518	5
1	1518	7
1	1518	8
1	1518	11
1	1518	12
1	1518	14
1	1518	16
1	1518	17
1	1518	20
1	1518	22
1	1518	24
1	1518	25
1	1519	1
1	1519	4
1	1519	6
1	1519	8
1	1519	13
1	1519	14
1	1519	16
1	1519	17
1	1519	18
1	1519	20
1	1519	21
1	1519	22
1	1519	23
1	1519	24
1	1519	25
1	1520	1
1	1520	2
1	1520	4
1	1520	8
1	1520	9
1	1520	10
1	1520	12
1	1520	13
1	1520	14
1	1520	16
1	1520	17
1	1520	18
1	1520	19
1	1520	24
1	1520	25
1	1521	1
1	1521	2
1	1521	3
1	1521	4
1	1521	5
1	1521	7
1	1521	8
1	1521	12
1	1521	14
1	1521	15
1	1521	17
1	1521	19
1	1521	20
1	1521	23
1	1521	24
1	1522	1
1	1522	8
1	1522	9
1	1522	10
1	1522	11
1	1522	13
1	1522	14
1	1522	15
1	1522	16
1	1522	18
1	1522	19
1	1522	20
1	1522	21
1	1522	23
1	1522	24
1	1523	3
1	1523	5
1	1523	6
1	1523	7
1	1523	9
1	1523	10
1	1523	12
1	1523	13
1	1523	14
1	1523	16
1	1523	18
1	1523	19
1	1523	21
1	1523	23
1	1523	25
1	1524	1
1	1524	3
1	1524	5
1	1524	6
1	1524	7
1	1524	8
1	1524	9
1	1524	10
1	1524	13
1	1524	14
1	1524	20
1	1524	22
1	1524	23
1	1524	24
1	1524	25
1	1525	1
1	1525	2
1	1525	4
1	1525	5
1	1525	8
1	1525	10
1	1525	12
1	1525	14
1	1525	15
1	1525	18
1	1525	19
1	1525	20
1	1525	21
1	1525	22
1	1525	25
1	1526	5
1	1526	7
1	1526	8
1	1526	9
1	1526	10
1	1526	11
1	1526	13
1	1526	15
1	1526	17
1	1526	18
1	1526	20
1	1526	21
1	1526	22
1	1526	23
1	1526	25
1	1527	1
1	1527	2
1	1527	3
1	1527	5
1	1527	6
1	1527	7
1	1527	9
1	1527	10
1	1527	14
1	1527	15
1	1527	20
1	1527	21
1	1527	22
1	1527	24
1	1527	25
1	1528	1
1	1528	2
1	1528	4
1	1528	5
1	1528	6
1	1528	8
1	1528	9
1	1528	10
1	1528	17
1	1528	18
1	1528	20
1	1528	21
1	1528	23
1	1528	24
1	1528	25
1	1529	2
1	1529	3
1	1529	4
1	1529	5
1	1529	8
1	1529	11
1	1529	13
1	1529	14
1	1529	16
1	1529	17
1	1529	18
1	1529	19
1	1529	20
1	1529	21
1	1529	24
1	1530	2
1	1530	4
1	1530	5
1	1530	7
1	1530	9
1	1530	10
1	1530	12
1	1530	14
1	1530	15
1	1530	16
1	1530	18
1	1530	20
1	1530	22
1	1530	23
1	1530	24
1	1531	1
1	1531	2
1	1531	3
1	1531	4
1	1531	7
1	1531	8
1	1531	10
1	1531	11
1	1531	13
1	1531	14
1	1531	15
1	1531	19
1	1531	22
1	1531	23
1	1531	24
1	1532	1
1	1532	2
1	1532	3
1	1532	8
1	1532	9
1	1532	10
1	1532	11
1	1532	12
1	1532	13
1	1532	14
1	1532	17
1	1532	18
1	1532	20
1	1532	22
1	1532	25
1	1533	1
1	1533	3
1	1533	4
1	1533	6
1	1533	7
1	1533	11
1	1533	12
1	1533	13
1	1533	14
1	1533	15
1	1533	16
1	1533	19
1	1533	20
1	1533	21
1	1533	24
1	1534	1
1	1534	4
1	1534	5
1	1534	8
1	1534	9
1	1534	10
1	1534	11
1	1534	12
1	1534	13
1	1534	14
1	1534	16
1	1534	17
1	1534	19
1	1534	21
1	1534	24
1	1535	3
1	1535	4
1	1535	5
1	1535	7
1	1535	8
1	1535	12
1	1535	13
1	1535	15
1	1535	17
1	1535	18
1	1535	21
1	1535	22
1	1535	23
1	1535	24
1	1535	25
1	1536	1
1	1536	3
1	1536	5
1	1536	6
1	1536	7
1	1536	8
1	1536	9
1	1536	10
1	1536	11
1	1536	12
1	1536	13
1	1536	19
1	1536	20
1	1536	23
1	1536	25
1	1537	1
1	1537	2
1	1537	3
1	1537	4
1	1537	10
1	1537	11
1	1537	13
1	1537	14
1	1537	15
1	1537	17
1	1537	18
1	1537	20
1	1537	21
1	1537	22
1	1537	24
1	1538	2
1	1538	4
1	1538	5
1	1538	7
1	1538	8
1	1538	9
1	1538	10
1	1538	13
1	1538	14
1	1538	15
1	1538	17
1	1538	18
1	1538	19
1	1538	21
1	1538	23
1	1539	1
1	1539	3
1	1539	4
1	1539	8
1	1539	11
1	1539	12
1	1539	13
1	1539	14
1	1539	16
1	1539	17
1	1539	18
1	1539	19
1	1539	20
1	1539	21
1	1539	25
1	1540	1
1	1540	2
1	1540	3
1	1540	7
1	1540	9
1	1540	10
1	1540	11
1	1540	12
1	1540	14
1	1540	15
1	1540	16
1	1540	17
1	1540	19
1	1540	22
1	1540	23
1	1541	2
1	1541	3
1	1541	4
1	1541	5
1	1541	7
1	1541	11
1	1541	13
1	1541	14
1	1541	15
1	1541	18
1	1541	19
1	1541	20
1	1541	21
1	1541	22
1	1541	25
1	1542	2
1	1542	3
1	1542	5
1	1542	7
1	1542	8
1	1542	10
1	1542	11
1	1542	13
1	1542	15
1	1542	16
1	1542	17
1	1542	20
1	1542	21
1	1542	22
1	1542	24
1	1543	1
1	1543	2
1	1543	6
1	1543	7
1	1543	8
1	1543	9
1	1543	12
1	1543	13
1	1543	15
1	1543	17
1	1543	19
1	1543	20
1	1543	23
1	1543	24
1	1543	25
1	1544	1
1	1544	2
1	1544	4
1	1544	7
1	1544	8
1	1544	9
1	1544	11
1	1544	12
1	1544	14
1	1544	16
1	1544	17
1	1544	21
1	1544	22
1	1544	23
1	1544	24
1	1545	3
1	1545	5
1	1545	7
1	1545	8
1	1545	10
1	1545	11
1	1545	12
1	1545	15
1	1545	16
1	1545	17
1	1545	20
1	1545	22
1	1545	23
1	1545	24
1	1545	25
1	1546	1
1	1546	3
1	1546	6
1	1546	7
1	1546	8
1	1546	10
1	1546	11
1	1546	14
1	1546	15
1	1546	18
1	1546	19
1	1546	20
1	1546	22
1	1546	24
1	1546	25
1	1547	1
1	1547	2
1	1547	5
1	1547	6
1	1547	8
1	1547	9
1	1547	10
1	1547	11
1	1547	13
1	1547	15
1	1547	17
1	1547	18
1	1547	19
1	1547	21
1	1547	25
1	1548	2
1	1548	3
1	1548	4
1	1548	9
1	1548	10
1	1548	11
1	1548	12
1	1548	14
1	1548	15
1	1548	17
1	1548	18
1	1548	20
1	1548	21
1	1548	22
1	1548	23
1	1549	1
1	1549	2
1	1549	3
1	1549	4
1	1549	5
1	1549	7
1	1549	8
1	1549	10
1	1549	11
1	1549	13
1	1549	18
1	1549	20
1	1549	23
1	1549	24
1	1549	25
1	1550	3
1	1550	4
1	1550	5
1	1550	7
1	1550	8
1	1550	13
1	1550	14
1	1550	15
1	1550	16
1	1550	17
1	1550	20
1	1550	22
1	1550	23
1	1550	24
1	1550	25
1	1551	1
1	1551	3
1	1551	5
1	1551	7
1	1551	8
1	1551	11
1	1551	13
1	1551	14
1	1551	15
1	1551	17
1	1551	19
1	1551	20
1	1551	22
1	1551	23
1	1551	25
1	1552	2
1	1552	3
1	1552	7
1	1552	8
1	1552	9
1	1552	12
1	1552	14
1	1552	15
1	1552	16
1	1552	19
1	1552	20
1	1552	21
1	1552	22
1	1552	24
1	1552	25
1	1553	1
1	1553	2
1	1553	4
1	1553	8
1	1553	9
1	1553	11
1	1553	12
1	1553	13
1	1553	15
1	1553	17
1	1553	18
1	1553	19
1	1553	21
1	1553	22
1	1553	25
1	1554	1
1	1554	3
1	1554	4
1	1554	5
1	1554	7
1	1554	8
1	1554	9
1	1554	10
1	1554	13
1	1554	14
1	1554	16
1	1554	18
1	1554	19
1	1554	24
1	1554	25
1	1555	1
1	1555	2
1	1555	6
1	1555	8
1	1555	9
1	1555	10
1	1555	12
1	1555	13
1	1555	14
1	1555	16
1	1555	18
1	1555	20
1	1555	22
1	1555	23
1	1555	25
1	1556	1
1	1556	2
1	1556	3
1	1556	5
1	1556	6
1	1556	8
1	1556	12
1	1556	15
1	1556	16
1	1556	17
1	1556	19
1	1556	21
1	1556	22
1	1556	23
1	1556	25
1	1557	2
1	1557	3
1	1557	4
1	1557	5
1	1557	6
1	1557	9
1	1557	12
1	1557	16
1	1557	17
1	1557	18
1	1557	20
1	1557	21
1	1557	22
1	1557	24
1	1557	25
1	1558	1
1	1558	2
1	1558	4
1	1558	5
1	1558	6
1	1558	9
1	1558	11
1	1558	14
1	1558	15
1	1558	16
1	1558	17
1	1558	18
1	1558	21
1	1558	22
1	1558	25
1	1559	3
1	1559	4
1	1559	5
1	1559	6
1	1559	7
1	1559	9
1	1559	10
1	1559	11
1	1559	14
1	1559	16
1	1559	18
1	1559	19
1	1559	20
1	1559	23
1	1559	25
1	1560	1
1	1560	2
1	1560	3
1	1560	4
1	1560	5
1	1560	7
1	1560	8
1	1560	9
1	1560	11
1	1560	14
1	1560	17
1	1560	18
1	1560	20
1	1560	24
1	1560	25
1	1561	3
1	1561	5
1	1561	6
1	1561	7
1	1561	8
1	1561	12
1	1561	13
1	1561	15
1	1561	16
1	1561	18
1	1561	20
1	1561	21
1	1561	22
1	1561	24
1	1561	25
1	1562	1
1	1562	2
1	1562	3
1	1562	4
1	1562	5
1	1562	6
1	1562	7
1	1562	8
1	1562	9
1	1562	11
1	1562	12
1	1562	14
1	1562	16
1	1562	17
1	1562	18
1	1563	1
1	1563	2
1	1563	3
1	1563	5
1	1563	6
1	1563	9
1	1563	10
1	1563	12
1	1563	13
1	1563	17
1	1563	18
1	1563	20
1	1563	21
1	1563	22
1	1563	23
1	1564	3
1	1564	4
1	1564	6
1	1564	8
1	1564	9
1	1564	11
1	1564	12
1	1564	13
1	1564	16
1	1564	17
1	1564	18
1	1564	19
1	1564	20
1	1564	21
1	1564	24
1	1565	1
1	1565	3
1	1565	6
1	1565	7
1	1565	8
1	1565	9
1	1565	10
1	1565	11
1	1565	12
1	1565	13
1	1565	15
1	1565	17
1	1565	18
1	1565	24
1	1565	25
1	1566	1
1	1566	2
1	1566	4
1	1566	5
1	1566	7
1	1566	8
1	1566	9
1	1566	13
1	1566	14
1	1566	15
1	1566	16
1	1566	19
1	1566	23
1	1566	24
1	1566	25
1	1567	2
1	1567	3
1	1567	5
1	1567	7
1	1567	9
1	1567	10
1	1567	11
1	1567	12
1	1567	14
1	1567	15
1	1567	17
1	1567	18
1	1567	19
1	1567	21
1	1567	24
1	1568	1
1	1568	2
1	1568	3
1	1568	4
1	1568	6
1	1568	7
1	1568	10
1	1568	11
1	1568	13
1	1568	16
1	1568	17
1	1568	19
1	1568	21
1	1568	22
1	1568	24
1	1569	2
1	1569	4
1	1569	8
1	1569	9
1	1569	10
1	1569	12
1	1569	13
1	1569	14
1	1569	16
1	1569	18
1	1569	20
1	1569	21
1	1569	23
1	1569	24
1	1569	25
1	1570	1
1	1570	3
1	1570	7
1	1570	8
1	1570	9
1	1570	11
1	1570	13
1	1570	16
1	1570	18
1	1570	19
1	1570	20
1	1570	21
1	1570	23
1	1570	24
1	1570	25
1	1571	1
1	1571	3
1	1571	4
1	1571	5
1	1571	6
1	1571	7
1	1571	11
1	1571	12
1	1571	14
1	1571	17
1	1571	18
1	1571	19
1	1571	23
1	1571	24
1	1571	25
1	1572	2
1	1572	4
1	1572	5
1	1572	6
1	1572	8
1	1572	9
1	1572	10
1	1572	13
1	1572	16
1	1572	18
1	1572	19
1	1572	21
1	1572	22
1	1572	23
1	1572	24
1	1573	2
1	1573	6
1	1573	7
1	1573	8
1	1573	10
1	1573	11
1	1573	12
1	1573	13
1	1573	14
1	1573	15
1	1573	16
1	1573	17
1	1573	18
1	1573	19
1	1573	23
1	1574	1
1	1574	2
1	1574	3
1	1574	5
1	1574	6
1	1574	7
1	1574	10
1	1574	11
1	1574	12
1	1574	14
1	1574	15
1	1574	17
1	1574	18
1	1574	21
1	1574	22
1	1575	1
1	1575	3
1	1575	5
1	1575	6
1	1575	7
1	1575	9
1	1575	10
1	1575	11
1	1575	12
1	1575	14
1	1575	16
1	1575	17
1	1575	22
1	1575	23
1	1575	25
1	1576	1
1	1576	2
1	1576	5
1	1576	7
1	1576	8
1	1576	9
1	1576	11
1	1576	12
1	1576	14
1	1576	15
1	1576	16
1	1576	18
1	1576	20
1	1576	21
1	1576	25
1	1577	3
1	1577	5
1	1577	6
1	1577	7
1	1577	9
1	1577	10
1	1577	11
1	1577	13
1	1577	15
1	1577	16
1	1577	17
1	1577	18
1	1577	19
1	1577	21
1	1577	24
1	1578	4
1	1578	6
1	1578	8
1	1578	9
1	1578	10
1	1578	12
1	1578	13
1	1578	14
1	1578	16
1	1578	17
1	1578	18
1	1578	19
1	1578	21
1	1578	22
1	1578	24
1	1579	1
1	1579	2
1	1579	4
1	1579	6
1	1579	7
1	1579	10
1	1579	12
1	1579	13
1	1579	14
1	1579	15
1	1579	16
1	1579	18
1	1579	21
1	1579	22
1	1579	23
1	1580	3
1	1580	4
1	1580	7
1	1580	10
1	1580	11
1	1580	12
1	1580	13
1	1580	14
1	1580	15
1	1580	16
1	1580	18
1	1580	20
1	1580	22
1	1580	23
1	1580	25
1	1581	3
1	1581	4
1	1581	5
1	1581	6
1	1581	7
1	1581	8
1	1581	11
1	1581	12
1	1581	13
1	1581	16
1	1581	20
1	1581	21
1	1581	23
1	1581	24
1	1581	25
1	1582	1
1	1582	2
1	1582	5
1	1582	7
1	1582	8
1	1582	10
1	1582	11
1	1582	14
1	1582	16
1	1582	17
1	1582	18
1	1582	19
1	1582	23
1	1582	24
1	1582	25
1	1583	2
1	1583	3
1	1583	4
1	1583	6
1	1583	7
1	1583	9
1	1583	10
1	1583	14
1	1583	15
1	1583	16
1	1583	17
1	1583	19
1	1583	20
1	1583	23
1	1583	25
1	1584	1
1	1584	2
1	1584	3
1	1584	5
1	1584	6
1	1584	11
1	1584	12
1	1584	14
1	1584	15
1	1584	16
1	1584	17
1	1584	19
1	1584	20
1	1584	24
1	1584	25
1	1585	1
1	1585	2
1	1585	4
1	1585	5
1	1585	6
1	1585	7
1	1585	9
1	1585	11
1	1585	17
1	1585	18
1	1585	19
1	1585	21
1	1585	23
1	1585	24
1	1585	25
1	1586	1
1	1586	3
1	1586	4
1	1586	10
1	1586	11
1	1586	12
1	1586	13
1	1586	16
1	1586	18
1	1586	19
1	1586	20
1	1586	22
1	1586	23
1	1586	24
1	1586	25
1	1587	2
1	1587	3
1	1587	5
1	1587	7
1	1587	8
1	1587	11
1	1587	14
1	1587	15
1	1587	16
1	1587	17
1	1587	19
1	1587	20
1	1587	21
1	1587	22
1	1587	25
1	1588	1
1	1588	3
1	1588	4
1	1588	5
1	1588	7
1	1588	9
1	1588	10
1	1588	11
1	1588	14
1	1588	15
1	1588	17
1	1588	20
1	1588	21
1	1588	22
1	1588	23
1	1589	1
1	1589	2
1	1589	3
1	1589	4
1	1589	6
1	1589	12
1	1589	13
1	1589	14
1	1589	15
1	1589	17
1	1589	18
1	1589	22
1	1589	23
1	1589	24
1	1589	25
1	1590	1
1	1590	3
1	1590	5
1	1590	7
1	1590	8
1	1590	10
1	1590	14
1	1590	16
1	1590	17
1	1590	18
1	1590	20
1	1590	21
1	1590	22
1	1590	23
1	1590	25
1	1591	1
1	1591	3
1	1591	5
1	1591	7
1	1591	8
1	1591	10
1	1591	11
1	1591	12
1	1591	17
1	1591	19
1	1591	20
1	1591	21
1	1591	22
1	1591	23
1	1591	24
1	1592	1
1	1592	2
1	1592	3
1	1592	4
1	1592	5
1	1592	6
1	1592	9
1	1592	12
1	1592	14
1	1592	15
1	1592	16
1	1592	19
1	1592	20
1	1592	22
1	1592	25
1	1593	3
1	1593	4
1	1593	5
1	1593	7
1	1593	8
1	1593	9
1	1593	10
1	1593	11
1	1593	13
1	1593	14
1	1593	16
1	1593	17
1	1593	20
1	1593	22
1	1593	24
1	1594	1
1	1594	2
1	1594	4
1	1594	6
1	1594	8
1	1594	10
1	1594	11
1	1594	12
1	1594	13
1	1594	15
1	1594	16
1	1594	17
1	1594	19
1	1594	21
1	1594	25
1	1595	1
1	1595	2
1	1595	3
1	1595	4
1	1595	6
1	1595	7
1	1595	9
1	1595	10
1	1595	11
1	1595	13
1	1595	17
1	1595	18
1	1595	20
1	1595	22
1	1595	25
1	1596	5
1	1596	8
1	1596	9
1	1596	10
1	1596	11
1	1596	12
1	1596	13
1	1596	15
1	1596	18
1	1596	19
1	1596	20
1	1596	21
1	1596	22
1	1596	23
1	1596	24
1	1597	1
1	1597	2
1	1597	5
1	1597	6
1	1597	7
1	1597	8
1	1597	9
1	1597	13
1	1597	17
1	1597	18
1	1597	19
1	1597	20
1	1597	21
1	1597	22
1	1597	24
1	1598	2
1	1598	5
1	1598	6
1	1598	7
1	1598	10
1	1598	12
1	1598	13
1	1598	15
1	1598	16
1	1598	17
1	1598	18
1	1598	19
1	1598	20
1	1598	21
1	1598	24
1	1599	1
1	1599	3
1	1599	4
1	1599	5
1	1599	6
1	1599	8
1	1599	9
1	1599	10
1	1599	14
1	1599	18
1	1599	20
1	1599	21
1	1599	22
1	1599	23
1	1599	25
1	1600	2
1	1600	3
1	1600	4
1	1600	5
1	1600	7
1	1600	9
1	1600	13
1	1600	14
1	1600	16
1	1600	17
1	1600	18
1	1600	20
1	1600	22
1	1600	23
1	1600	24
1	1601	2
1	1601	4
1	1601	6
1	1601	8
1	1601	9
1	1601	10
1	1601	11
1	1601	12
1	1601	13
1	1601	14
1	1601	15
1	1601	18
1	1601	20
1	1601	22
1	1601	25
1	1602	1
1	1602	3
1	1602	4
1	1602	8
1	1602	9
1	1602	10
1	1602	11
1	1602	13
1	1602	14
1	1602	15
1	1602	17
1	1602	19
1	1602	21
1	1602	23
1	1602	24
1	1603	1
1	1603	2
1	1603	3
1	1603	4
1	1603	7
1	1603	9
1	1603	10
1	1603	13
1	1603	14
1	1603	16
1	1603	19
1	1603	20
1	1603	21
1	1603	23
1	1603	24
1	1604	3
1	1604	4
1	1604	5
1	1604	6
1	1604	7
1	1604	8
1	1604	9
1	1604	10
1	1604	12
1	1604	13
1	1604	15
1	1604	19
1	1604	21
1	1604	22
1	1604	24
1	1605	2
1	1605	4
1	1605	5
1	1605	8
1	1605	9
1	1605	10
1	1605	11
1	1605	14
1	1605	16
1	1605	17
1	1605	18
1	1605	19
1	1605	21
1	1605	23
1	1605	25
1	1606	1
1	1606	3
1	1606	5
1	1606	7
1	1606	8
1	1606	9
1	1606	10
1	1606	11
1	1606	14
1	1606	15
1	1606	19
1	1606	20
1	1606	22
1	1606	23
1	1606	25
1	1607	1
1	1607	2
1	1607	3
1	1607	6
1	1607	7
1	1607	8
1	1607	9
1	1607	11
1	1607	12
1	1607	13
1	1607	14
1	1607	15
1	1607	17
1	1607	18
1	1607	24
1	1608	1
1	1608	2
1	1608	3
1	1608	5
1	1608	6
1	1608	9
1	1608	10
1	1608	14
1	1608	17
1	1608	18
1	1608	20
1	1608	21
1	1608	22
1	1608	23
1	1608	25
1	1609	5
1	1609	6
1	1609	7
1	1609	8
1	1609	9
1	1609	11
1	1609	13
1	1609	14
1	1609	17
1	1609	18
1	1609	20
1	1609	21
1	1609	23
1	1609	24
1	1609	25
1	1610	3
1	1610	6
1	1610	7
1	1610	9
1	1610	10
1	1610	11
1	1610	13
1	1610	14
1	1610	16
1	1610	17
1	1610	19
1	1610	20
1	1610	21
1	1610	22
1	1610	24
1	1611	1
1	1611	3
1	1611	4
1	1611	6
1	1611	7
1	1611	8
1	1611	9
1	1611	10
1	1611	11
1	1611	12
1	1611	14
1	1611	15
1	1611	20
1	1611	22
1	1611	24
1	1612	2
1	1612	3
1	1612	4
1	1612	5
1	1612	7
1	1612	11
1	1612	12
1	1612	14
1	1612	15
1	1612	18
1	1612	21
1	1612	22
1	1612	23
1	1612	24
1	1612	25
1	1613	1
1	1613	2
1	1613	3
1	1613	4
1	1613	6
1	1613	8
1	1613	9
1	1613	10
1	1613	13
1	1613	14
1	1613	16
1	1613	17
1	1613	18
1	1613	19
1	1613	21
1	1614	1
1	1614	2
1	1614	3
1	1614	7
1	1614	9
1	1614	10
1	1614	12
1	1614	13
1	1614	14
1	1614	15
1	1614	16
1	1614	17
1	1614	19
1	1614	21
1	1614	23
1	1615	1
1	1615	2
1	1615	4
1	1615	5
1	1615	6
1	1615	7
1	1615	9
1	1615	10
1	1615	11
1	1615	16
1	1615	17
1	1615	19
1	1615	20
1	1615	21
1	1615	25
1	1616	1
1	1616	2
1	1616	4
1	1616	5
1	1616	8
1	1616	10
1	1616	11
1	1616	13
1	1616	14
1	1616	16
1	1616	17
1	1616	18
1	1616	22
1	1616	23
1	1616	24
1	1617	2
1	1617	5
1	1617	6
1	1617	7
1	1617	8
1	1617	9
1	1617	10
1	1617	12
1	1617	13
1	1617	14
1	1617	15
1	1617	20
1	1617	22
1	1617	23
1	1617	25
1	1618	1
1	1618	3
1	1618	4
1	1618	5
1	1618	8
1	1618	9
1	1618	10
1	1618	13
1	1618	14
1	1618	16
1	1618	17
1	1618	19
1	1618	20
1	1618	24
1	1618	25
1	1619	4
1	1619	5
1	1619	7
1	1619	8
1	1619	10
1	1619	11
1	1619	13
1	1619	15
1	1619	16
1	1619	17
1	1619	18
1	1619	21
1	1619	22
1	1619	24
1	1619	25
1	1620	1
1	1620	2
1	1620	4
1	1620	7
1	1620	9
1	1620	10
1	1620	11
1	1620	12
1	1620	13
1	1620	14
1	1620	18
1	1620	20
1	1620	21
1	1620	24
1	1620	25
1	1621	2
1	1621	3
1	1621	4
1	1621	6
1	1621	8
1	1621	9
1	1621	10
1	1621	13
1	1621	14
1	1621	18
1	1621	19
1	1621	21
1	1621	22
1	1621	23
1	1621	24
1	1622	1
1	1622	2
1	1622	3
1	1622	4
1	1622	8
1	1622	9
1	1622	11
1	1622	16
1	1622	17
1	1622	18
1	1622	20
1	1622	22
1	1622	23
1	1622	24
1	1622	25
1	1623	1
1	1623	2
1	1623	3
1	1623	4
1	1623	6
1	1623	7
1	1623	8
1	1623	10
1	1623	11
1	1623	13
1	1623	14
1	1623	17
1	1623	19
1	1623	20
1	1623	24
1	1624	1
1	1624	2
1	1624	6
1	1624	7
1	1624	8
1	1624	9
1	1624	11
1	1624	14
1	1624	15
1	1624	16
1	1624	17
1	1624	18
1	1624	20
1	1624	23
1	1624	24
1	1625	2
1	1625	3
1	1625	6
1	1625	8
1	1625	10
1	1625	12
1	1625	13
1	1625	16
1	1625	17
1	1625	18
1	1625	19
1	1625	20
1	1625	21
1	1625	22
1	1625	24
1	1626	1
1	1626	3
1	1626	4
1	1626	7
1	1626	8
1	1626	9
1	1626	10
1	1626	11
1	1626	13
1	1626	15
1	1626	16
1	1626	17
1	1626	20
1	1626	21
1	1626	24
1	1627	2
1	1627	3
1	1627	4
1	1627	6
1	1627	8
1	1627	9
1	1627	11
1	1627	12
1	1627	13
1	1627	14
1	1627	15
1	1627	17
1	1627	20
1	1627	21
1	1627	24
1	1628	1
1	1628	3
1	1628	6
1	1628	9
1	1628	11
1	1628	12
1	1628	16
1	1628	17
1	1628	18
1	1628	19
1	1628	20
1	1628	22
1	1628	23
1	1628	24
1	1628	25
1	1629	1
1	1629	2
1	1629	3
1	1629	5
1	1629	6
1	1629	7
1	1629	9
1	1629	10
1	1629	12
1	1629	14
1	1629	15
1	1629	18
1	1629	22
1	1629	24
1	1629	25
1	1630	3
1	1630	5
1	1630	7
1	1630	8
1	1630	9
1	1630	10
1	1630	12
1	1630	13
1	1630	14
1	1630	15
1	1630	17
1	1630	20
1	1630	22
1	1630	23
1	1630	25
1	1631	2
1	1631	3
1	1631	4
1	1631	5
1	1631	9
1	1631	10
1	1631	11
1	1631	12
1	1631	14
1	1631	18
1	1631	19
1	1631	20
1	1631	22
1	1631	23
1	1631	25
1	1632	4
1	1632	5
1	1632	8
1	1632	12
1	1632	13
1	1632	14
1	1632	15
1	1632	16
1	1632	18
1	1632	20
1	1632	21
1	1632	22
1	1632	23
1	1632	24
1	1632	25
1	1633	1
1	1633	2
1	1633	3
1	1633	5
1	1633	6
1	1633	7
1	1633	9
1	1633	10
1	1633	17
1	1633	18
1	1633	19
1	1633	20
1	1633	23
1	1633	24
1	1633	25
1	1634	3
1	1634	4
1	1634	5
1	1634	6
1	1634	7
1	1634	9
1	1634	10
1	1634	13
1	1634	14
1	1634	15
1	1634	19
1	1634	21
1	1634	22
1	1634	24
1	1634	25
1	1635	1
1	1635	3
1	1635	6
1	1635	7
1	1635	8
1	1635	12
1	1635	15
1	1635	16
1	1635	17
1	1635	19
1	1635	21
1	1635	22
1	1635	23
1	1635	24
1	1635	25
1	1636	2
1	1636	3
1	1636	6
1	1636	7
1	1636	8
1	1636	9
1	1636	12
1	1636	13
1	1636	14
1	1636	15
1	1636	18
1	1636	19
1	1636	20
1	1636	22
1	1636	25
1	1637	3
1	1637	4
1	1637	5
1	1637	7
1	1637	8
1	1637	11
1	1637	12
1	1637	13
1	1637	14
1	1637	15
1	1637	17
1	1637	18
1	1637	19
1	1637	22
1	1637	24
1	1638	1
1	1638	7
1	1638	8
1	1638	10
1	1638	11
1	1638	12
1	1638	14
1	1638	15
1	1638	16
1	1638	19
1	1638	20
1	1638	22
1	1638	23
1	1638	24
1	1638	25
1	1639	1
1	1639	3
1	1639	5
1	1639	6
1	1639	7
1	1639	8
1	1639	9
1	1639	10
1	1639	11
1	1639	14
1	1639	15
1	1639	19
1	1639	20
1	1639	22
1	1639	25
1	1640	1
1	1640	2
1	1640	4
1	1640	5
1	1640	6
1	1640	12
1	1640	14
1	1640	15
1	1640	16
1	1640	17
1	1640	20
1	1640	21
1	1640	22
1	1640	24
1	1640	25
1	1641	3
1	1641	4
1	1641	5
1	1641	8
1	1641	9
1	1641	11
1	1641	12
1	1641	14
1	1641	16
1	1641	17
1	1641	19
1	1641	20
1	1641	21
1	1641	22
1	1641	25
1	1642	2
1	1642	5
1	1642	6
1	1642	7
1	1642	10
1	1642	11
1	1642	13
1	1642	15
1	1642	17
1	1642	18
1	1642	19
1	1642	20
1	1642	22
1	1642	24
1	1642	25
1	1643	1
1	1643	2
1	1643	3
1	1643	4
1	1643	5
1	1643	7
1	1643	9
1	1643	10
1	1643	12
1	1643	14
1	1643	16
1	1643	19
1	1643	22
1	1643	23
1	1643	25
1	1644	2
1	1644	3
1	1644	4
1	1644	5
1	1644	6
1	1644	7
1	1644	8
1	1644	9
1	1644	11
1	1644	13
1	1644	15
1	1644	18
1	1644	22
1	1644	23
1	1644	24
1	1645	2
1	1645	3
1	1645	4
1	1645	5
1	1645	8
1	1645	9
1	1645	10
1	1645	14
1	1645	15
1	1645	16
1	1645	18
1	1645	20
1	1645	21
1	1645	23
1	1645	25
1	1646	1
1	1646	3
1	1646	4
1	1646	5
1	1646	6
1	1646	7
1	1646	9
1	1646	12
1	1646	13
1	1646	15
1	1646	17
1	1646	18
1	1646	20
1	1646	22
1	1646	25
1	1647	1
1	1647	2
1	1647	4
1	1647	7
1	1647	8
1	1647	9
1	1647	10
1	1647	12
1	1647	14
1	1647	15
1	1647	19
1	1647	20
1	1647	22
1	1647	24
1	1647	25
1	1648	4
1	1648	9
1	1648	10
1	1648	11
1	1648	12
1	1648	13
1	1648	15
1	1648	16
1	1648	17
1	1648	19
1	1648	21
1	1648	22
1	1648	23
1	1648	24
1	1648	25
1	1649	4
1	1649	5
1	1649	8
1	1649	9
1	1649	12
1	1649	13
1	1649	14
1	1649	15
1	1649	16
1	1649	17
1	1649	18
1	1649	20
1	1649	22
1	1649	23
1	1649	24
1	1650	3
1	1650	4
1	1650	5
1	1650	8
1	1650	10
1	1650	13
1	1650	14
1	1650	15
1	1650	16
1	1650	17
1	1650	18
1	1650	19
1	1650	20
1	1650	22
1	1650	25
1	1651	1
1	1651	2
1	1651	3
1	1651	4
1	1651	6
1	1651	7
1	1651	8
1	1651	10
1	1651	16
1	1651	17
1	1651	18
1	1651	19
1	1651	20
1	1651	22
1	1651	24
1	1652	2
1	1652	3
1	1652	4
1	1652	5
1	1652	6
1	1652	7
1	1652	10
1	1652	11
1	1652	14
1	1652	16
1	1652	17
1	1652	18
1	1652	21
1	1652	24
1	1652	25
1	1653	2
1	1653	4
1	1653	5
1	1653	6
1	1653	7
1	1653	12
1	1653	14
1	1653	15
1	1653	17
1	1653	20
1	1653	21
1	1653	22
1	1653	23
1	1653	24
1	1653	25
1	1654	1
1	1654	2
1	1654	3
1	1654	4
1	1654	6
1	1654	10
1	1654	11
1	1654	13
1	1654	16
1	1654	18
1	1654	19
1	1654	20
1	1654	22
1	1654	23
1	1654	25
1	1655	1
1	1655	2
1	1655	3
1	1655	5
1	1655	6
1	1655	7
1	1655	10
1	1655	12
1	1655	14
1	1655	16
1	1655	18
1	1655	19
1	1655	20
1	1655	22
1	1655	23
1	1656	2
1	1656	3
1	1656	4
1	1656	5
1	1656	7
1	1656	10
1	1656	11
1	1656	12
1	1656	13
1	1656	15
1	1656	17
1	1656	19
1	1656	20
1	1656	23
1	1656	24
1	1657	3
1	1657	4
1	1657	6
1	1657	8
1	1657	9
1	1657	10
1	1657	12
1	1657	15
1	1657	17
1	1657	18
1	1657	19
1	1657	20
1	1657	21
1	1657	23
1	1657	24
1	1658	2
1	1658	4
1	1658	5
1	1658	6
1	1658	7
1	1658	8
1	1658	12
1	1658	13
1	1658	15
1	1658	16
1	1658	17
1	1658	18
1	1658	19
1	1658	20
1	1658	23
1	1659	2
1	1659	4
1	1659	7
1	1659	8
1	1659	9
1	1659	10
1	1659	12
1	1659	14
1	1659	15
1	1659	16
1	1659	20
1	1659	21
1	1659	22
1	1659	23
1	1659	25
1	1660	1
1	1660	2
1	1660	3
1	1660	7
1	1660	8
1	1660	10
1	1660	11
1	1660	13
1	1660	14
1	1660	17
1	1660	18
1	1660	20
1	1660	21
1	1660	24
1	1660	25
1	1661	2
1	1661	3
1	1661	5
1	1661	6
1	1661	7
1	1661	10
1	1661	11
1	1661	12
1	1661	13
1	1661	14
1	1661	17
1	1661	18
1	1661	21
1	1661	22
1	1661	23
1	1662	1
1	1662	2
1	1662	3
1	1662	5
1	1662	8
1	1662	10
1	1662	11
1	1662	13
1	1662	14
1	1662	17
1	1662	18
1	1662	20
1	1662	21
1	1662	22
1	1662	25
1	1663	1
1	1663	2
1	1663	3
1	1663	5
1	1663	6
1	1663	7
1	1663	9
1	1663	11
1	1663	12
1	1663	13
1	1663	16
1	1663	17
1	1663	21
1	1663	22
1	1663	23
1	1664	2
1	1664	4
1	1664	5
1	1664	6
1	1664	7
1	1664	8
1	1664	11
1	1664	13
1	1664	15
1	1664	16
1	1664	17
1	1664	18
1	1664	20
1	1664	24
1	1664	25
1	1665	1
1	1665	2
1	1665	4
1	1665	5
1	1665	8
1	1665	10
1	1665	12
1	1665	13
1	1665	15
1	1665	17
1	1665	18
1	1665	21
1	1665	22
1	1665	23
1	1665	24
1	1666	1
1	1666	2
1	1666	5
1	1666	6
1	1666	8
1	1666	9
1	1666	10
1	1666	12
1	1666	13
1	1666	14
1	1666	17
1	1666	20
1	1666	21
1	1666	24
1	1666	25
1	1667	1
1	1667	2
1	1667	3
1	1667	4
1	1667	8
1	1667	10
1	1667	11
1	1667	13
1	1667	16
1	1667	18
1	1667	20
1	1667	22
1	1667	23
1	1667	24
1	1667	25
1	1668	4
1	1668	5
1	1668	6
1	1668	8
1	1668	11
1	1668	12
1	1668	14
1	1668	16
1	1668	17
1	1668	18
1	1668	20
1	1668	21
1	1668	23
1	1668	24
1	1668	25
1	1669	1
1	1669	2
1	1669	3
1	1669	5
1	1669	6
1	1669	7
1	1669	8
1	1669	9
1	1669	12
1	1669	16
1	1669	17
1	1669	20
1	1669	21
1	1669	23
1	1669	25
1	1670	1
1	1670	2
1	1670	3
1	1670	4
1	1670	7
1	1670	11
1	1670	13
1	1670	14
1	1670	16
1	1670	17
1	1670	20
1	1670	21
1	1670	22
1	1670	23
1	1670	25
1	1671	1
1	1671	3
1	1671	4
1	1671	5
1	1671	8
1	1671	9
1	1671	10
1	1671	12
1	1671	14
1	1671	15
1	1671	18
1	1671	19
1	1671	21
1	1671	22
1	1671	25
1	1672	2
1	1672	3
1	1672	5
1	1672	6
1	1672	8
1	1672	9
1	1672	11
1	1672	17
1	1672	18
1	1672	20
1	1672	21
1	1672	22
1	1672	23
1	1672	24
1	1672	25
1	1673	1
1	1673	2
1	1673	4
1	1673	5
1	1673	7
1	1673	9
1	1673	11
1	1673	12
1	1673	15
1	1673	17
1	1673	19
1	1673	20
1	1673	23
1	1673	24
1	1673	25
1	1674	1
1	1674	2
1	1674	4
1	1674	5
1	1674	9
1	1674	10
1	1674	11
1	1674	12
1	1674	15
1	1674	19
1	1674	20
1	1674	21
1	1674	22
1	1674	23
1	1674	24
1	1675	1
1	1675	2
1	1675	3
1	1675	5
1	1675	7
1	1675	8
1	1675	9
1	1675	12
1	1675	14
1	1675	19
1	1675	20
1	1675	21
1	1675	22
1	1675	23
1	1675	25
1	1676	3
1	1676	4
1	1676	8
1	1676	9
1	1676	10
1	1676	12
1	1676	13
1	1676	14
1	1676	15
1	1676	16
1	1676	18
1	1676	20
1	1676	23
1	1676	24
1	1676	25
1	1677	1
1	1677	4
1	1677	5
1	1677	6
1	1677	9
1	1677	11
1	1677	12
1	1677	14
1	1677	15
1	1677	16
1	1677	17
1	1677	18
1	1677	19
1	1677	20
1	1677	22
1	1678	1
1	1678	3
1	1678	4
1	1678	5
1	1678	6
1	1678	8
1	1678	9
1	1678	14
1	1678	16
1	1678	18
1	1678	19
1	1678	20
1	1678	22
1	1678	23
1	1678	24
1	1679	5
1	1679	7
1	1679	8
1	1679	9
1	1679	10
1	1679	11
1	1679	12
1	1679	14
1	1679	15
1	1679	16
1	1679	17
1	1679	19
1	1679	20
1	1679	21
1	1679	23
1	1680	1
1	1680	2
1	1680	3
1	1680	7
1	1680	8
1	1680	10
1	1680	11
1	1680	12
1	1680	13
1	1680	14
1	1680	18
1	1680	20
1	1680	21
1	1680	23
1	1680	25
1	1681	1
1	1681	2
1	1681	3
1	1681	7
1	1681	8
1	1681	10
1	1681	11
1	1681	12
1	1681	15
1	1681	16
1	1681	17
1	1681	20
1	1681	22
1	1681	23
1	1681	25
1	1682	1
1	1682	4
1	1682	5
1	1682	6
1	1682	7
1	1682	9
1	1682	12
1	1682	13
1	1682	15
1	1682	17
1	1682	18
1	1682	19
1	1682	20
1	1682	21
1	1682	25
1	1683	1
1	1683	2
1	1683	3
1	1683	5
1	1683	9
1	1683	10
1	1683	11
1	1683	13
1	1683	15
1	1683	16
1	1683	17
1	1683	18
1	1683	23
1	1683	24
1	1683	25
1	1684	2
1	1684	4
1	1684	7
1	1684	9
1	1684	10
1	1684	12
1	1684	13
1	1684	14
1	1684	15
1	1684	16
1	1684	17
1	1684	22
1	1684	23
1	1684	24
1	1684	25
1	1685	1
1	1685	2
1	1685	3
1	1685	5
1	1685	6
1	1685	7
1	1685	11
1	1685	12
1	1685	14
1	1685	16
1	1685	17
1	1685	19
1	1685	21
1	1685	22
1	1685	24
1	1686	2
1	1686	4
1	1686	5
1	1686	6
1	1686	9
1	1686	10
1	1686	13
1	1686	15
1	1686	17
1	1686	18
1	1686	19
1	1686	20
1	1686	22
1	1686	23
1	1686	24
1	1687	1
1	1687	2
1	1687	3
1	1687	4
1	1687	6
1	1687	7
1	1687	9
1	1687	10
1	1687	14
1	1687	16
1	1687	17
1	1687	18
1	1687	19
1	1687	20
1	1687	24
1	1688	1
1	1688	3
1	1688	4
1	1688	5
1	1688	6
1	1688	7
1	1688	8
1	1688	10
1	1688	13
1	1688	15
1	1688	19
1	1688	21
1	1688	22
1	1688	24
1	1688	25
1	1689	1
1	1689	2
1	1689	6
1	1689	7
1	1689	9
1	1689	10
1	1689	11
1	1689	13
1	1689	14
1	1689	16
1	1689	17
1	1689	18
1	1689	19
1	1689	22
1	1689	23
1	1690	1
1	1690	2
1	1690	4
1	1690	5
1	1690	7
1	1690	8
1	1690	10
1	1690	13
1	1690	15
1	1690	16
1	1690	19
1	1690	20
1	1690	22
1	1690	23
1	1690	25
1	1691	1
1	1691	2
1	1691	3
1	1691	4
1	1691	5
1	1691	7
1	1691	8
1	1691	10
1	1691	11
1	1691	12
1	1691	13
1	1691	15
1	1691	16
1	1691	18
1	1691	19
1	1692	3
1	1692	5
1	1692	6
1	1692	7
1	1692	10
1	1692	12
1	1692	14
1	1692	15
1	1692	17
1	1692	18
1	1692	20
1	1692	22
1	1692	23
1	1692	24
1	1692	25
1	1693	1
1	1693	3
1	1693	4
1	1693	6
1	1693	7
1	1693	8
1	1693	11
1	1693	14
1	1693	16
1	1693	17
1	1693	19
1	1693	20
1	1693	21
1	1693	22
1	1693	23
1	1694	1
1	1694	2
1	1694	3
1	1694	4
1	1694	5
1	1694	9
1	1694	11
1	1694	12
1	1694	13
1	1694	17
1	1694	18
1	1694	19
1	1694	20
1	1694	23
1	1694	24
1	1695	1
1	1695	4
1	1695	5
1	1695	9
1	1695	11
1	1695	13
1	1695	14
1	1695	17
1	1695	18
1	1695	20
1	1695	21
1	1695	22
1	1695	23
1	1695	24
1	1695	25
1	1696	2
1	1696	4
1	1696	5
1	1696	7
1	1696	8
1	1696	10
1	1696	12
1	1696	13
1	1696	14
1	1696	16
1	1696	17
1	1696	18
1	1696	19
1	1696	23
1	1696	24
1	1697	3
1	1697	4
1	1697	6
1	1697	7
1	1697	10
1	1697	13
1	1697	17
1	1697	18
1	1697	19
1	1697	20
1	1697	21
1	1697	22
1	1697	23
1	1697	24
1	1697	25
1	1698	2
1	1698	3
1	1698	4
1	1698	5
1	1698	8
1	1698	9
1	1698	13
1	1698	14
1	1698	16
1	1698	18
1	1698	19
1	1698	20
1	1698	21
1	1698	22
1	1698	25
1	1699	4
1	1699	5
1	1699	6
1	1699	8
1	1699	9
1	1699	10
1	1699	13
1	1699	14
1	1699	15
1	1699	16
1	1699	19
1	1699	21
1	1699	23
1	1699	24
1	1699	25
1	1700	1
1	1700	2
1	1700	3
1	1700	6
1	1700	7
1	1700	8
1	1700	12
1	1700	13
1	1700	14
1	1700	16
1	1700	20
1	1700	21
1	1700	22
1	1700	23
1	1700	24
1	1701	1
1	1701	2
1	1701	3
1	1701	5
1	1701	6
1	1701	7
1	1701	8
1	1701	10
1	1701	13
1	1701	16
1	1701	17
1	1701	18
1	1701	20
1	1701	21
1	1701	22
1	1702	3
1	1702	4
1	1702	5
1	1702	7
1	1702	8
1	1702	10
1	1702	11
1	1702	14
1	1702	15
1	1702	16
1	1702	17
1	1702	18
1	1702	19
1	1702	22
1	1702	25
1	1703	1
1	1703	3
1	1703	6
1	1703	8
1	1703	9
1	1703	10
1	1703	12
1	1703	13
1	1703	14
1	1703	15
1	1703	16
1	1703	17
1	1703	18
1	1703	19
1	1703	22
1	1704	2
1	1704	4
1	1704	6
1	1704	7
1	1704	9
1	1704	10
1	1704	11
1	1704	12
1	1704	13
1	1704	14
1	1704	16
1	1704	18
1	1704	19
1	1704	20
1	1704	22
1	1705	2
1	1705	3
1	1705	4
1	1705	5
1	1705	9
1	1705	12
1	1705	14
1	1705	16
1	1705	17
1	1705	18
1	1705	19
1	1705	20
1	1705	21
1	1705	23
1	1705	24
1	1706	2
1	1706	3
1	1706	4
1	1706	5
1	1706	7
1	1706	8
1	1706	9
1	1706	12
1	1706	13
1	1706	14
1	1706	15
1	1706	17
1	1706	18
1	1706	20
1	1706	21
1	1707	2
1	1707	5
1	1707	9
1	1707	10
1	1707	11
1	1707	12
1	1707	13
1	1707	16
1	1707	17
1	1707	18
1	1707	19
1	1707	21
1	1707	22
1	1707	23
1	1707	25
1	1708	1
1	1708	2
1	1708	3
1	1708	4
1	1708	6
1	1708	7
1	1708	8
1	1708	9
1	1708	10
1	1708	12
1	1708	13
1	1708	14
1	1708	17
1	1708	18
1	1708	22
1	1709	1
1	1709	3
1	1709	4
1	1709	5
1	1709	11
1	1709	12
1	1709	13
1	1709	15
1	1709	18
1	1709	19
1	1709	20
1	1709	21
1	1709	22
1	1709	23
1	1709	24
1	1710	2
1	1710	4
1	1710	5
1	1710	6
1	1710	7
1	1710	9
1	1710	10
1	1710	11
1	1710	12
1	1710	17
1	1710	20
1	1710	21
1	1710	22
1	1710	24
1	1710	25
1	1711	1
1	1711	2
1	1711	3
1	1711	4
1	1711	5
1	1711	8
1	1711	10
1	1711	11
1	1711	13
1	1711	14
1	1711	18
1	1711	19
1	1711	20
1	1711	21
1	1711	23
1	1712	1
1	1712	3
1	1712	5
1	1712	6
1	1712	7
1	1712	10
1	1712	13
1	1712	14
1	1712	15
1	1712	16
1	1712	17
1	1712	18
1	1712	23
1	1712	24
1	1712	25
1	1713	1
1	1713	4
1	1713	8
1	1713	9
1	1713	10
1	1713	12
1	1713	13
1	1713	15
1	1713	16
1	1713	17
1	1713	19
1	1713	20
1	1713	21
1	1713	23
1	1713	24
1	1714	1
1	1714	3
1	1714	5
1	1714	6
1	1714	7
1	1714	8
1	1714	10
1	1714	14
1	1714	15
1	1714	18
1	1714	19
1	1714	21
1	1714	22
1	1714	23
1	1714	24
1	1715	1
1	1715	2
1	1715	4
1	1715	6
1	1715	8
1	1715	11
1	1715	13
1	1715	16
1	1715	17
1	1715	18
1	1715	19
1	1715	21
1	1715	22
1	1715	24
1	1715	25
1	1716	1
1	1716	3
1	1716	4
1	1716	5
1	1716	7
1	1716	10
1	1716	11
1	1716	12
1	1716	13
1	1716	16
1	1716	17
1	1716	22
1	1716	23
1	1716	24
1	1716	25
1	1717	1
1	1717	3
1	1717	4
1	1717	5
1	1717	7
1	1717	8
1	1717	9
1	1717	10
1	1717	11
1	1717	14
1	1717	15
1	1717	21
1	1717	22
1	1717	23
1	1717	24
1	1718	2
1	1718	3
1	1718	5
1	1718	6
1	1718	7
1	1718	8
1	1718	10
1	1718	11
1	1718	12
1	1718	17
1	1718	18
1	1718	20
1	1718	21
1	1718	22
1	1718	24
1	1719	2
1	1719	3
1	1719	4
1	1719	6
1	1719	10
1	1719	11
1	1719	13
1	1719	15
1	1719	17
1	1719	18
1	1719	20
1	1719	21
1	1719	23
1	1719	24
1	1719	25
1	1720	2
1	1720	3
1	1720	4
1	1720	9
1	1720	10
1	1720	11
1	1720	13
1	1720	15
1	1720	17
1	1720	18
1	1720	20
1	1720	22
1	1720	23
1	1720	24
1	1720	25
1	1721	1
1	1721	3
1	1721	4
1	1721	5
1	1721	6
1	1721	8
1	1721	11
1	1721	13
1	1721	14
1	1721	15
1	1721	16
1	1721	19
1	1721	21
1	1721	24
1	1721	25
1	1722	2
1	1722	4
1	1722	5
1	1722	7
1	1722	8
1	1722	11
1	1722	12
1	1722	14
1	1722	15
1	1722	17
1	1722	19
1	1722	21
1	1722	22
1	1722	23
1	1722	25
1	1723	1
1	1723	2
1	1723	4
1	1723	6
1	1723	7
1	1723	10
1	1723	11
1	1723	12
1	1723	13
1	1723	14
1	1723	17
1	1723	18
1	1723	19
1	1723	21
1	1723	22
1	1724	5
1	1724	6
1	1724	7
1	1724	9
1	1724	10
1	1724	11
1	1724	12
1	1724	13
1	1724	15
1	1724	16
1	1724	18
1	1724	20
1	1724	21
1	1724	22
1	1724	23
1	1725	1
1	1725	5
1	1725	6
1	1725	8
1	1725	12
1	1725	13
1	1725	14
1	1725	15
1	1725	18
1	1725	19
1	1725	21
1	1725	22
1	1725	23
1	1725	24
1	1725	25
1	1726	1
1	1726	3
1	1726	5
1	1726	6
1	1726	8
1	1726	10
1	1726	11
1	1726	12
1	1726	14
1	1726	15
1	1726	17
1	1726	19
1	1726	20
1	1726	22
1	1726	25
1	1727	1
1	1727	2
1	1727	5
1	1727	6
1	1727	7
1	1727	9
1	1727	10
1	1727	13
1	1727	14
1	1727	15
1	1727	16
1	1727	20
1	1727	21
1	1727	22
1	1727	24
1	1728	2
1	1728	3
1	1728	5
1	1728	6
1	1728	7
1	1728	8
1	1728	9
1	1728	10
1	1728	11
1	1728	12
1	1728	14
1	1728	15
1	1728	17
1	1728	21
1	1728	22
1	1729	1
1	1729	2
1	1729	4
1	1729	6
1	1729	8
1	1729	9
1	1729	10
1	1729	11
1	1729	12
1	1729	14
1	1729	16
1	1729	18
1	1729	21
1	1729	24
1	1729	25
1	1730	1
1	1730	7
1	1730	8
1	1730	10
1	1730	12
1	1730	13
1	1730	14
1	1730	15
1	1730	16
1	1730	18
1	1730	19
1	1730	22
1	1730	23
1	1730	24
1	1730	25
1	1731	1
1	1731	3
1	1731	5
1	1731	7
1	1731	8
1	1731	9
1	1731	10
1	1731	13
1	1731	14
1	1731	17
1	1731	19
1	1731	20
1	1731	22
1	1731	24
1	1731	25
1	1732	1
1	1732	3
1	1732	5
1	1732	9
1	1732	10
1	1732	12
1	1732	13
1	1732	14
1	1732	17
1	1732	18
1	1732	19
1	1732	20
1	1732	21
1	1732	22
1	1732	24
1	1733	1
1	1733	2
1	1733	4
1	1733	5
1	1733	8
1	1733	9
1	1733	12
1	1733	13
1	1733	14
1	1733	15
1	1733	16
1	1733	19
1	1733	21
1	1733	23
1	1733	25
1	1734	1
1	1734	2
1	1734	3
1	1734	6
1	1734	7
1	1734	8
1	1734	10
1	1734	11
1	1734	15
1	1734	16
1	1734	17
1	1734	21
1	1734	22
1	1734	24
1	1734	25
1	1735	1
1	1735	2
1	1735	3
1	1735	6
1	1735	10
1	1735	12
1	1735	13
1	1735	14
1	1735	15
1	1735	19
1	1735	20
1	1735	21
1	1735	23
1	1735	24
1	1735	25
1	1736	3
1	1736	6
1	1736	7
1	1736	9
1	1736	11
1	1736	12
1	1736	13
1	1736	15
1	1736	16
1	1736	18
1	1736	19
1	1736	22
1	1736	23
1	1736	24
1	1736	25
1	1737	2
1	1737	4
1	1737	5
1	1737	6
1	1737	10
1	1737	11
1	1737	12
1	1737	15
1	1737	16
1	1737	18
1	1737	19
1	1737	20
1	1737	22
1	1737	24
1	1737	25
1	1738	1
1	1738	3
1	1738	6
1	1738	9
1	1738	10
1	1738	13
1	1738	14
1	1738	17
1	1738	18
1	1738	19
1	1738	20
1	1738	21
1	1738	22
1	1738	23
1	1738	24
1	1739	2
1	1739	3
1	1739	4
1	1739	5
1	1739	6
1	1739	7
1	1739	8
1	1739	11
1	1739	12
1	1739	14
1	1739	16
1	1739	19
1	1739	20
1	1739	22
1	1739	24
1	1740	1
1	1740	2
1	1740	3
1	1740	4
1	1740	5
1	1740	6
1	1740	8
1	1740	9
1	1740	10
1	1740	11
1	1740	16
1	1740	18
1	1740	19
1	1740	22
1	1740	24
1	1741	1
1	1741	5
1	1741	8
1	1741	11
1	1741	12
1	1741	15
1	1741	16
1	1741	17
1	1741	18
1	1741	19
1	1741	20
1	1741	21
1	1741	22
1	1741	23
1	1741	25
1	1742	1
1	1742	4
1	1742	6
1	1742	8
1	1742	9
1	1742	10
1	1742	12
1	1742	14
1	1742	15
1	1742	16
1	1742	17
1	1742	18
1	1742	20
1	1742	21
1	1742	25
1	1743	5
1	1743	6
1	1743	7
1	1743	8
1	1743	10
1	1743	11
1	1743	13
1	1743	15
1	1743	17
1	1743	18
1	1743	19
1	1743	21
1	1743	22
1	1743	24
1	1743	25
1	1744	1
1	1744	5
1	1744	6
1	1744	10
1	1744	11
1	1744	12
1	1744	13
1	1744	15
1	1744	17
1	1744	18
1	1744	19
1	1744	20
1	1744	21
1	1744	23
1	1744	24
1	1745	2
1	1745	3
1	1745	4
1	1745	6
1	1745	7
1	1745	8
1	1745	9
1	1745	10
1	1745	11
1	1745	16
1	1745	18
1	1745	20
1	1745	21
1	1745	24
1	1745	25
1	1746	3
1	1746	4
1	1746	6
1	1746	7
1	1746	8
1	1746	9
1	1746	10
1	1746	11
1	1746	12
1	1746	15
1	1746	16
1	1746	19
1	1746	22
1	1746	23
1	1746	25
1	1747	1
1	1747	4
1	1747	5
1	1747	6
1	1747	7
1	1747	8
1	1747	10
1	1747	13
1	1747	15
1	1747	16
1	1747	17
1	1747	19
1	1747	20
1	1747	21
1	1747	25
1	1748	1
1	1748	3
1	1748	5
1	1748	6
1	1748	7
1	1748	9
1	1748	10
1	1748	11
1	1748	12
1	1748	17
1	1748	18
1	1748	19
1	1748	21
1	1748	22
1	1748	25
1	1749	2
1	1749	4
1	1749	6
1	1749	9
1	1749	12
1	1749	13
1	1749	15
1	1749	16
1	1749	19
1	1749	20
1	1749	21
1	1749	22
1	1749	23
1	1749	24
1	1749	25
1	1750	1
1	1750	4
1	1750	6
1	1750	7
1	1750	10
1	1750	12
1	1750	13
1	1750	16
1	1750	17
1	1750	18
1	1750	19
1	1750	20
1	1750	22
1	1750	23
1	1750	24
1	1751	1
1	1751	3
1	1751	4
1	1751	6
1	1751	7
1	1751	9
1	1751	10
1	1751	12
1	1751	13
1	1751	15
1	1751	18
1	1751	19
1	1751	22
1	1751	24
1	1751	25
1	1752	1
1	1752	3
1	1752	4
1	1752	6
1	1752	7
1	1752	8
1	1752	9
1	1752	12
1	1752	13
1	1752	15
1	1752	16
1	1752	17
1	1752	18
1	1752	20
1	1752	22
1	1753	1
1	1753	2
1	1753	3
1	1753	5
1	1753	6
1	1753	8
1	1753	9
1	1753	12
1	1753	13
1	1753	15
1	1753	17
1	1753	21
1	1753	22
1	1753	24
1	1753	25
1	1754	1
1	1754	2
1	1754	3
1	1754	4
1	1754	5
1	1754	10
1	1754	12
1	1754	13
1	1754	14
1	1754	15
1	1754	17
1	1754	20
1	1754	21
1	1754	24
1	1754	25
1	1755	1
1	1755	2
1	1755	3
1	1755	8
1	1755	9
1	1755	11
1	1755	13
1	1755	16
1	1755	18
1	1755	19
1	1755	20
1	1755	21
1	1755	22
1	1755	23
1	1755	25
1	1756	1
1	1756	2
1	1756	5
1	1756	6
1	1756	7
1	1756	8
1	1756	12
1	1756	13
1	1756	16
1	1756	17
1	1756	19
1	1756	21
1	1756	22
1	1756	23
1	1756	24
1	1757	1
1	1757	3
1	1757	4
1	1757	7
1	1757	10
1	1757	13
1	1757	14
1	1757	15
1	1757	17
1	1757	18
1	1757	20
1	1757	21
1	1757	22
1	1757	23
1	1757	25
1	1758	1
1	1758	2
1	1758	4
1	1758	7
1	1758	8
1	1758	9
1	1758	10
1	1758	12
1	1758	13
1	1758	14
1	1758	17
1	1758	19
1	1758	20
1	1758	22
1	1758	23
1	1759	1
1	1759	2
1	1759	3
1	1759	4
1	1759	5
1	1759	6
1	1759	8
1	1759	10
1	1759	14
1	1759	15
1	1759	16
1	1759	18
1	1759	19
1	1759	22
1	1759	23
1	1760	1
1	1760	3
1	1760	4
1	1760	5
1	1760	6
1	1760	7
1	1760	12
1	1760	14
1	1760	15
1	1760	16
1	1760	18
1	1760	20
1	1760	23
1	1760	24
1	1760	25
1	1761	1
1	1761	2
1	1761	3
1	1761	5
1	1761	6
1	1761	9
1	1761	10
1	1761	11
1	1761	13
1	1761	17
1	1761	18
1	1761	19
1	1761	20
1	1761	21
1	1761	25
1	1762	1
1	1762	2
1	1762	5
1	1762	6
1	1762	7
1	1762	8
1	1762	12
1	1762	15
1	1762	16
1	1762	17
1	1762	20
1	1762	21
1	1762	22
1	1762	23
1	1762	25
1	1763	1
1	1763	2
1	1763	3
1	1763	4
1	1763	5
1	1763	8
1	1763	9
1	1763	10
1	1763	11
1	1763	13
1	1763	14
1	1763	15
1	1763	16
1	1763	21
1	1763	24
1	1764	1
1	1764	2
1	1764	4
1	1764	6
1	1764	7
1	1764	10
1	1764	12
1	1764	14
1	1764	15
1	1764	16
1	1764	17
1	1764	19
1	1764	20
1	1764	23
1	1764	25
1	1765	1
1	1765	2
1	1765	3
1	1765	4
1	1765	5
1	1765	8
1	1765	9
1	1765	11
1	1765	13
1	1765	14
1	1765	17
1	1765	18
1	1765	21
1	1765	22
1	1765	25
1	1766	1
1	1766	3
1	1766	7
1	1766	8
1	1766	9
1	1766	10
1	1766	11
1	1766	12
1	1766	13
1	1766	14
1	1766	15
1	1766	16
1	1766	20
1	1766	21
1	1766	23
1	1767	2
1	1767	4
1	1767	5
1	1767	6
1	1767	7
1	1767	9
1	1767	10
1	1767	11
1	1767	15
1	1767	16
1	1767	19
1	1767	20
1	1767	23
1	1767	24
1	1767	25
1	1768	1
1	1768	2
1	1768	4
1	1768	6
1	1768	10
1	1768	12
1	1768	14
1	1768	17
1	1768	18
1	1768	19
1	1768	20
1	1768	22
1	1768	23
1	1768	24
1	1768	25
1	1769	1
1	1769	3
1	1769	5
1	1769	7
1	1769	8
1	1769	10
1	1769	12
1	1769	13
1	1769	14
1	1769	16
1	1769	17
1	1769	18
1	1769	20
1	1769	23
1	1769	25
1	1770	2
1	1770	4
1	1770	5
1	1770	7
1	1770	11
1	1770	12
1	1770	14
1	1770	15
1	1770	18
1	1770	19
1	1770	20
1	1770	21
1	1770	22
1	1770	23
1	1770	25
1	1771	2
1	1771	6
1	1771	7
1	1771	10
1	1771	11
1	1771	13
1	1771	15
1	1771	16
1	1771	17
1	1771	18
1	1771	19
1	1771	21
1	1771	23
1	1771	24
1	1771	25
1	1772	1
1	1772	3
1	1772	4
1	1772	5
1	1772	7
1	1772	9
1	1772	10
1	1772	13
1	1772	14
1	1772	16
1	1772	19
1	1772	20
1	1772	21
1	1772	24
1	1772	25
1	1773	1
1	1773	2
1	1773	5
1	1773	8
1	1773	9
1	1773	10
1	1773	13
1	1773	15
1	1773	16
1	1773	17
1	1773	18
1	1773	19
1	1773	21
1	1773	24
1	1773	25
1	1774	3
1	1774	7
1	1774	9
1	1774	10
1	1774	12
1	1774	13
1	1774	14
1	1774	15
1	1774	17
1	1774	19
1	1774	20
1	1774	22
1	1774	23
1	1774	24
1	1774	25
1	1775	3
1	1775	6
1	1775	7
1	1775	8
1	1775	9
1	1775	11
1	1775	12
1	1775	14
1	1775	15
1	1775	16
1	1775	17
1	1775	18
1	1775	19
1	1775	20
1	1775	23
1	1776	2
1	1776	3
1	1776	4
1	1776	6
1	1776	7
1	1776	11
1	1776	12
1	1776	13
1	1776	17
1	1776	18
1	1776	19
1	1776	22
1	1776	23
1	1776	24
1	1776	25
1	1777	2
1	1777	4
1	1777	6
1	1777	8
1	1777	10
1	1777	12
1	1777	14
1	1777	15
1	1777	16
1	1777	18
1	1777	19
1	1777	20
1	1777	21
1	1777	24
1	1777	25
1	1778	1
1	1778	3
1	1778	5
1	1778	6
1	1778	8
1	1778	9
1	1778	10
1	1778	11
1	1778	13
1	1778	16
1	1778	18
1	1778	19
1	1778	21
1	1778	23
1	1778	24
1	1779	2
1	1779	3
1	1779	4
1	1779	6
1	1779	8
1	1779	9
1	1779	15
1	1779	18
1	1779	19
1	1779	20
1	1779	21
1	1779	22
1	1779	23
1	1779	24
1	1779	25
1	1780	3
1	1780	4
1	1780	5
1	1780	6
1	1780	8
1	1780	9
1	1780	10
1	1780	11
1	1780	13
1	1780	14
1	1780	15
1	1780	16
1	1780	17
1	1780	22
1	1780	25
1	1781	1
1	1781	4
1	1781	5
1	1781	7
1	1781	8
1	1781	9
1	1781	10
1	1781	11
1	1781	15
1	1781	16
1	1781	18
1	1781	19
1	1781	20
1	1781	21
1	1781	22
1	1782	1
1	1782	2
1	1782	3
1	1782	7
1	1782	8
1	1782	12
1	1782	13
1	1782	14
1	1782	15
1	1782	17
1	1782	18
1	1782	19
1	1782	20
1	1782	22
1	1782	25
1	1783	3
1	1783	4
1	1783	8
1	1783	10
1	1783	11
1	1783	12
1	1783	14
1	1783	15
1	1783	18
1	1783	20
1	1783	21
1	1783	22
1	1783	23
1	1783	24
1	1783	25
1	1784	1
1	1784	3
1	1784	4
1	1784	7
1	1784	9
1	1784	10
1	1784	11
1	1784	13
1	1784	14
1	1784	17
1	1784	18
1	1784	19
1	1784	22
1	1784	23
1	1784	25
1	1785	1
1	1785	4
1	1785	5
1	1785	6
1	1785	7
1	1785	8
1	1785	9
1	1785	11
1	1785	14
1	1785	16
1	1785	17
1	1785	19
1	1785	21
1	1785	23
1	1785	25
1	1786	1
1	1786	3
1	1786	4
1	1786	5
1	1786	6
1	1786	7
1	1786	12
1	1786	16
1	1786	17
1	1786	18
1	1786	20
1	1786	21
1	1786	22
1	1786	23
1	1786	24
1	1787	1
1	1787	2
1	1787	4
1	1787	6
1	1787	7
1	1787	10
1	1787	11
1	1787	12
1	1787	14
1	1787	18
1	1787	19
1	1787	20
1	1787	21
1	1787	23
1	1787	25
1	1788	1
1	1788	2
1	1788	6
1	1788	7
1	1788	9
1	1788	10
1	1788	11
1	1788	13
1	1788	14
1	1788	15
1	1788	17
1	1788	18
1	1788	19
1	1788	20
1	1788	23
1	1789	1
1	1789	3
1	1789	5
1	1789	8
1	1789	9
1	1789	11
1	1789	13
1	1789	14
1	1789	15
1	1789	17
1	1789	19
1	1789	21
1	1789	22
1	1789	24
1	1789	25
1	1790	1
1	1790	2
1	1790	3
1	1790	6
1	1790	8
1	1790	11
1	1790	12
1	1790	13
1	1790	15
1	1790	17
1	1790	18
1	1790	21
1	1790	23
1	1790	24
1	1790	25
1	1791	1
1	1791	2
1	1791	4
1	1791	5
1	1791	7
1	1791	8
1	1791	10
1	1791	13
1	1791	15
1	1791	17
1	1791	18
1	1791	19
1	1791	20
1	1791	22
1	1791	24
1	1792	2
1	1792	3
1	1792	6
1	1792	7
1	1792	9
1	1792	10
1	1792	13
1	1792	14
1	1792	15
1	1792	16
1	1792	17
1	1792	21
1	1792	22
1	1792	24
1	1792	25
1	1793	1
1	1793	2
1	1793	3
1	1793	5
1	1793	6
1	1793	10
1	1793	11
1	1793	13
1	1793	16
1	1793	18
1	1793	19
1	1793	20
1	1793	21
1	1793	23
1	1793	24
1	1794	3
1	1794	4
1	1794	5
1	1794	7
1	1794	8
1	1794	10
1	1794	11
1	1794	13
1	1794	16
1	1794	18
1	1794	19
1	1794	21
1	1794	22
1	1794	24
1	1794	25
1	1795	2
1	1795	4
1	1795	7
1	1795	8
1	1795	9
1	1795	10
1	1795	13
1	1795	16
1	1795	17
1	1795	18
1	1795	19
1	1795	22
1	1795	23
1	1795	24
1	1795	25
1	1796	1
1	1796	3
1	1796	5
1	1796	9
1	1796	10
1	1796	12
1	1796	15
1	1796	16
1	1796	18
1	1796	19
1	1796	20
1	1796	21
1	1796	23
1	1796	24
1	1796	25
1	1797	3
1	1797	5
1	1797	6
1	1797	7
1	1797	9
1	1797	10
1	1797	11
1	1797	14
1	1797	15
1	1797	16
1	1797	17
1	1797	18
1	1797	19
1	1797	24
1	1797	25
1	1798	2
1	1798	3
1	1798	4
1	1798	5
1	1798	7
1	1798	9
1	1798	12
1	1798	13
1	1798	14
1	1798	15
1	1798	16
1	1798	19
1	1798	20
1	1798	21
1	1798	23
1	1799	2
1	1799	3
1	1799	4
1	1799	5
1	1799	8
1	1799	10
1	1799	11
1	1799	12
1	1799	15
1	1799	18
1	1799	20
1	1799	22
1	1799	23
1	1799	24
1	1799	25
1	1800	1
1	1800	2
1	1800	5
1	1800	6
1	1800	7
1	1800	8
1	1800	10
1	1800	12
1	1800	13
1	1800	14
1	1800	15
1	1800	16
1	1800	20
1	1800	21
1	1800	22
1	1801	1
1	1801	4
1	1801	5
1	1801	7
1	1801	10
1	1801	12
1	1801	13
1	1801	15
1	1801	17
1	1801	18
1	1801	19
1	1801	20
1	1801	22
1	1801	23
1	1801	24
1	1802	1
1	1802	2
1	1802	5
1	1802	8
1	1802	11
1	1802	12
1	1802	14
1	1802	15
1	1802	16
1	1802	19
1	1802	20
1	1802	21
1	1802	23
1	1802	24
1	1802	25
1	1803	3
1	1803	4
1	1803	5
1	1803	6
1	1803	7
1	1803	9
1	1803	11
1	1803	15
1	1803	17
1	1803	18
1	1803	19
1	1803	20
1	1803	21
1	1803	23
1	1803	24
1	1804	1
1	1804	5
1	1804	8
1	1804	9
1	1804	10
1	1804	11
1	1804	13
1	1804	14
1	1804	15
1	1804	17
1	1804	19
1	1804	20
1	1804	22
1	1804	24
1	1804	25
1	1805	1
1	1805	2
1	1805	4
1	1805	5
1	1805	6
1	1805	9
1	1805	10
1	1805	14
1	1805	15
1	1805	16
1	1805	18
1	1805	20
1	1805	22
1	1805	23
1	1805	24
1	1806	1
1	1806	2
1	1806	4
1	1806	5
1	1806	7
1	1806	9
1	1806	11
1	1806	14
1	1806	15
1	1806	16
1	1806	19
1	1806	20
1	1806	21
1	1806	23
1	1806	25
1	1807	1
1	1807	2
1	1807	3
1	1807	5
1	1807	7
1	1807	8
1	1807	9
1	1807	13
1	1807	14
1	1807	17
1	1807	18
1	1807	19
1	1807	20
1	1807	24
1	1807	25
1	1808	3
1	1808	5
1	1808	7
1	1808	8
1	1808	11
1	1808	12
1	1808	13
1	1808	15
1	1808	16
1	1808	18
1	1808	19
1	1808	20
1	1808	22
1	1808	24
1	1808	25
1	1809	1
1	1809	2
1	1809	4
1	1809	5
1	1809	6
1	1809	9
1	1809	13
1	1809	14
1	1809	16
1	1809	17
1	1809	18
1	1809	20
1	1809	23
1	1809	24
1	1809	25
1	1810	1
1	1810	3
1	1810	4
1	1810	6
1	1810	7
1	1810	9
1	1810	12
1	1810	13
1	1810	14
1	1810	16
1	1810	19
1	1810	21
1	1810	22
1	1810	24
1	1810	25
1	1811	2
1	1811	3
1	1811	4
1	1811	5
1	1811	6
1	1811	7
1	1811	8
1	1811	10
1	1811	12
1	1811	13
1	1811	14
1	1811	18
1	1811	20
1	1811	21
1	1811	24
1	1812	2
1	1812	4
1	1812	6
1	1812	7
1	1812	9
1	1812	11
1	1812	12
1	1812	13
1	1812	18
1	1812	19
1	1812	20
1	1812	21
1	1812	23
1	1812	24
1	1812	25
1	1813	1
1	1813	2
1	1813	4
1	1813	5
1	1813	7
1	1813	8
1	1813	11
1	1813	13
1	1813	14
1	1813	15
1	1813	16
1	1813	17
1	1813	20
1	1813	23
1	1813	25
1	1814	1
1	1814	2
1	1814	3
1	1814	5
1	1814	7
1	1814	12
1	1814	14
1	1814	15
1	1814	16
1	1814	18
1	1814	19
1	1814	21
1	1814	23
1	1814	24
1	1814	25
1	1815	3
1	1815	6
1	1815	7
1	1815	10
1	1815	11
1	1815	12
1	1815	13
1	1815	14
1	1815	15
1	1815	18
1	1815	19
1	1815	20
1	1815	21
1	1815	24
1	1815	25
1	1816	1
1	1816	2
1	1816	4
1	1816	6
1	1816	7
1	1816	8
1	1816	9
1	1816	11
1	1816	13
1	1816	14
1	1816	15
1	1816	16
1	1816	18
1	1816	20
1	1816	21
1	1817	1
1	1817	4
1	1817	7
1	1817	9
1	1817	10
1	1817	11
1	1817	14
1	1817	15
1	1817	16
1	1817	17
1	1817	18
1	1817	21
1	1817	22
1	1817	23
1	1817	24
1	1818	1
1	1818	4
1	1818	5
1	1818	6
1	1818	8
1	1818	9
1	1818	10
1	1818	11
1	1818	14
1	1818	15
1	1818	16
1	1818	19
1	1818	21
1	1818	23
1	1818	24
1	1819	1
1	1819	6
1	1819	9
1	1819	10
1	1819	11
1	1819	12
1	1819	13
1	1819	14
1	1819	15
1	1819	16
1	1819	17
1	1819	18
1	1819	19
1	1819	20
1	1819	23
1	1820	1
1	1820	4
1	1820	5
1	1820	7
1	1820	10
1	1820	13
1	1820	14
1	1820	16
1	1820	17
1	1820	18
1	1820	19
1	1820	20
1	1820	21
1	1820	22
1	1820	25
1	1821	2
1	1821	3
1	1821	4
1	1821	5
1	1821	7
1	1821	9
1	1821	10
1	1821	13
1	1821	14
1	1821	16
1	1821	17
1	1821	19
1	1821	20
1	1821	21
1	1821	25
1	1822	1
1	1822	4
1	1822	6
1	1822	9
1	1822	12
1	1822	13
1	1822	14
1	1822	16
1	1822	17
1	1822	18
1	1822	19
1	1822	20
1	1822	21
1	1822	24
1	1822	25
1	1823	3
1	1823	5
1	1823	6
1	1823	7
1	1823	8
1	1823	9
1	1823	10
1	1823	12
1	1823	13
1	1823	15
1	1823	16
1	1823	17
1	1823	18
1	1823	19
1	1823	22
1	1824	2
1	1824	5
1	1824	6
1	1824	8
1	1824	9
1	1824	11
1	1824	13
1	1824	14
1	1824	16
1	1824	17
1	1824	18
1	1824	20
1	1824	21
1	1824	23
1	1824	25
1	1825	1
1	1825	3
1	1825	7
1	1825	8
1	1825	9
1	1825	10
1	1825	11
1	1825	14
1	1825	15
1	1825	16
1	1825	17
1	1825	20
1	1825	21
1	1825	22
1	1825	23
1	1826	1
1	1826	2
1	1826	5
1	1826	7
1	1826	8
1	1826	9
1	1826	10
1	1826	11
1	1826	12
1	1826	13
1	1826	14
1	1826	19
1	1826	21
1	1826	22
1	1826	25
1	1827	1
1	1827	3
1	1827	4
1	1827	6
1	1827	7
1	1827	10
1	1827	12
1	1827	13
1	1827	14
1	1827	17
1	1827	18
1	1827	19
1	1827	21
1	1827	22
1	1827	24
1	1828	1
1	1828	2
1	1828	5
1	1828	6
1	1828	7
1	1828	8
1	1828	9
1	1828	11
1	1828	12
1	1828	13
1	1828	15
1	1828	19
1	1828	21
1	1828	23
1	1828	24
1	1829	2
1	1829	3
1	1829	4
1	1829	5
1	1829	7
1	1829	10
1	1829	11
1	1829	13
1	1829	15
1	1829	16
1	1829	19
1	1829	21
1	1829	22
1	1829	23
1	1829	24
1	1830	1
1	1830	3
1	1830	5
1	1830	8
1	1830	10
1	1830	11
1	1830	12
1	1830	14
1	1830	17
1	1830	18
1	1830	19
1	1830	20
1	1830	22
1	1830	23
1	1830	24
1	1831	2
1	1831	4
1	1831	5
1	1831	8
1	1831	9
1	1831	10
1	1831	12
1	1831	14
1	1831	16
1	1831	18
1	1831	19
1	1831	20
1	1831	21
1	1831	22
1	1831	23
1	1832	2
1	1832	7
1	1832	8
1	1832	9
1	1832	10
1	1832	11
1	1832	16
1	1832	18
1	1832	19
1	1832	20
1	1832	21
1	1832	22
1	1832	23
1	1832	24
1	1832	25
1	1833	1
1	1833	7
1	1833	9
1	1833	11
1	1833	12
1	1833	14
1	1833	15
1	1833	16
1	1833	18
1	1833	19
1	1833	20
1	1833	21
1	1833	23
1	1833	24
1	1833	25
1	1834	2
1	1834	5
1	1834	6
1	1834	8
1	1834	12
1	1834	13
1	1834	14
1	1834	15
1	1834	17
1	1834	18
1	1834	19
1	1834	20
1	1834	21
1	1834	22
1	1834	23
1	1835	1
1	1835	4
1	1835	6
1	1835	7
1	1835	11
1	1835	13
1	1835	14
1	1835	15
1	1835	16
1	1835	18
1	1835	20
1	1835	21
1	1835	22
1	1835	23
1	1835	24
1	1836	1
1	1836	3
1	1836	4
1	1836	6
1	1836	7
1	1836	8
1	1836	9
1	1836	12
1	1836	14
1	1836	15
1	1836	17
1	1836	18
1	1836	19
1	1836	24
1	1836	25
1	1837	1
1	1837	4
1	1837	5
1	1837	6
1	1837	8
1	1837	9
1	1837	11
1	1837	12
1	1837	13
1	1837	14
1	1837	15
1	1837	16
1	1837	21
1	1837	24
1	1837	25
1	1838	1
1	1838	3
1	1838	5
1	1838	8
1	1838	9
1	1838	10
1	1838	12
1	1838	15
1	1838	16
1	1838	18
1	1838	20
1	1838	21
1	1838	22
1	1838	23
1	1838	25
1	1839	1
1	1839	3
1	1839	4
1	1839	6
1	1839	7
1	1839	8
1	1839	9
1	1839	14
1	1839	15
1	1839	17
1	1839	18
1	1839	19
1	1839	23
1	1839	24
1	1839	25
1	1840	2
1	1840	3
1	1840	6
1	1840	7
1	1840	10
1	1840	11
1	1840	12
1	1840	13
1	1840	14
1	1840	15
1	1840	16
1	1840	17
1	1840	19
1	1840	21
1	1840	24
1	1841	1
1	1841	2
1	1841	3
1	1841	4
1	1841	6
1	1841	7
1	1841	8
1	1841	11
1	1841	12
1	1841	13
1	1841	17
1	1841	18
1	1841	21
1	1841	22
1	1841	25
1	1842	3
1	1842	4
1	1842	5
1	1842	6
1	1842	9
1	1842	11
1	1842	12
1	1842	13
1	1842	14
1	1842	16
1	1842	17
1	1842	19
1	1842	20
1	1842	21
1	1842	23
1	1843	4
1	1843	6
1	1843	7
1	1843	8
1	1843	11
1	1843	12
1	1843	14
1	1843	15
1	1843	16
1	1843	17
1	1843	19
1	1843	20
1	1843	21
1	1843	22
1	1843	24
1	1844	1
1	1844	3
1	1844	5
1	1844	6
1	1844	7
1	1844	8
1	1844	11
1	1844	12
1	1844	14
1	1844	15
1	1844	16
1	1844	17
1	1844	21
1	1844	23
1	1844	25
1	1845	3
1	1845	4
1	1845	5
1	1845	6
1	1845	8
1	1845	10
1	1845	11
1	1845	14
1	1845	15
1	1845	17
1	1845	18
1	1845	19
1	1845	20
1	1845	21
1	1845	23
1	1846	1
1	1846	2
1	1846	3
1	1846	9
1	1846	10
1	1846	11
1	1846	12
1	1846	14
1	1846	15
1	1846	18
1	1846	19
1	1846	20
1	1846	22
1	1846	24
1	1846	25
1	1847	1
1	1847	2
1	1847	3
1	1847	5
1	1847	7
1	1847	8
1	1847	9
1	1847	14
1	1847	15
1	1847	17
1	1847	18
1	1847	19
1	1847	20
1	1847	23
1	1847	24
1	1848	2
1	1848	3
1	1848	7
1	1848	8
1	1848	9
1	1848	11
1	1848	13
1	1848	15
1	1848	16
1	1848	17
1	1848	18
1	1848	20
1	1848	21
1	1848	22
1	1848	24
1	1849	1
1	1849	5
1	1849	9
1	1849	11
1	1849	12
1	1849	13
1	1849	14
1	1849	17
1	1849	18
1	1849	19
1	1849	21
1	1849	22
1	1849	23
1	1849	24
1	1849	25
1	1850	4
1	1850	5
1	1850	7
1	1850	10
1	1850	11
1	1850	12
1	1850	14
1	1850	15
1	1850	16
1	1850	18
1	1850	20
1	1850	21
1	1850	23
1	1850	24
1	1850	25
1	1851	1
1	1851	5
1	1851	6
1	1851	7
1	1851	8
1	1851	9
1	1851	10
1	1851	11
1	1851	13
1	1851	16
1	1851	19
1	1851	20
1	1851	22
1	1851	23
1	1851	25
1	1852	1
1	1852	3
1	1852	6
1	1852	9
1	1852	10
1	1852	12
1	1852	13
1	1852	17
1	1852	18
1	1852	19
1	1852	20
1	1852	21
1	1852	23
1	1852	24
1	1852	25
1	1853	1
1	1853	3
1	1853	5
1	1853	9
1	1853	10
1	1853	11
1	1853	13
1	1853	14
1	1853	15
1	1853	16
1	1853	17
1	1853	20
1	1853	22
1	1853	23
1	1853	24
1	1854	3
1	1854	4
1	1854	5
1	1854	6
1	1854	8
1	1854	11
1	1854	13
1	1854	14
1	1854	15
1	1854	16
1	1854	17
1	1854	18
1	1854	20
1	1854	22
1	1854	24
1	1855	1
1	1855	4
1	1855	5
1	1855	7
1	1855	11
1	1855	12
1	1855	13
1	1855	14
1	1855	15
1	1855	16
1	1855	17
1	1855	20
1	1855	23
1	1855	24
1	1855	25
1	1856	1
1	1856	3
1	1856	4
1	1856	7
1	1856	8
1	1856	10
1	1856	11
1	1856	12
1	1856	13
1	1856	16
1	1856	17
1	1856	18
1	1856	20
1	1856	21
1	1856	23
1	1857	2
1	1857	4
1	1857	6
1	1857	7
1	1857	8
1	1857	9
1	1857	14
1	1857	15
1	1857	16
1	1857	17
1	1857	20
1	1857	22
1	1857	23
1	1857	24
1	1857	25
1	1858	2
1	1858	3
1	1858	4
1	1858	7
1	1858	8
1	1858	9
1	1858	11
1	1858	13
1	1858	15
1	1858	17
1	1858	18
1	1858	20
1	1858	21
1	1858	22
1	1858	25
1	1859	3
1	1859	6
1	1859	7
1	1859	8
1	1859	9
1	1859	12
1	1859	13
1	1859	16
1	1859	17
1	1859	19
1	1859	20
1	1859	21
1	1859	22
1	1859	24
1	1859	25
1	1860	1
1	1860	2
1	1860	3
1	1860	4
1	1860	5
1	1860	10
1	1860	11
1	1860	15
1	1860	17
1	1860	18
1	1860	19
1	1860	21
1	1860	22
1	1860	23
1	1860	24
1	1861	2
1	1861	3
1	1861	5
1	1861	6
1	1861	7
1	1861	8
1	1861	9
1	1861	13
1	1861	14
1	1861	16
1	1861	18
1	1861	22
1	1861	23
1	1861	24
1	1861	25
1	1862	2
1	1862	3
1	1862	4
1	1862	5
1	1862	7
1	1862	10
1	1862	11
1	1862	13
1	1862	16
1	1862	18
1	1862	19
1	1862	20
1	1862	21
1	1862	23
1	1862	24
1	1863	2
1	1863	3
1	1863	4
1	1863	5
1	1863	6
1	1863	8
1	1863	9
1	1863	10
1	1863	14
1	1863	16
1	1863	18
1	1863	21
1	1863	22
1	1863	24
1	1863	25
1	1864	2
1	1864	3
1	1864	6
1	1864	7
1	1864	8
1	1864	9
1	1864	10
1	1864	12
1	1864	14
1	1864	16
1	1864	18
1	1864	20
1	1864	21
1	1864	24
1	1864	25
1	1865	2
1	1865	3
1	1865	5
1	1865	6
1	1865	7
1	1865	10
1	1865	11
1	1865	12
1	1865	14
1	1865	17
1	1865	19
1	1865	20
1	1865	21
1	1865	24
1	1865	25
1	1866	1
1	1866	2
1	1866	3
1	1866	4
1	1866	5
1	1866	10
1	1866	11
1	1866	12
1	1866	13
1	1866	14
1	1866	16
1	1866	20
1	1866	21
1	1866	23
1	1866	25
1	1867	1
1	1867	2
1	1867	4
1	1867	5
1	1867	6
1	1867	7
1	1867	8
1	1867	9
1	1867	12
1	1867	13
1	1867	15
1	1867	16
1	1867	17
1	1867	18
1	1867	25
1	1868	1
1	1868	2
1	1868	4
1	1868	5
1	1868	6
1	1868	8
1	1868	10
1	1868	11
1	1868	13
1	1868	14
1	1868	16
1	1868	17
1	1868	19
1	1868	21
1	1868	24
1	1869	1
1	1869	2
1	1869	4
1	1869	10
1	1869	11
1	1869	13
1	1869	14
1	1869	15
1	1869	17
1	1869	18
1	1869	21
1	1869	22
1	1869	23
1	1869	24
1	1869	25
1	1870	1
1	1870	2
1	1870	3
1	1870	4
1	1870	6
1	1870	7
1	1870	10
1	1870	15
1	1870	16
1	1870	18
1	1870	20
1	1870	21
1	1870	22
1	1870	24
1	1870	25
1	1871	1
1	1871	2
1	1871	4
1	1871	5
1	1871	6
1	1871	7
1	1871	8
1	1871	11
1	1871	13
1	1871	14
1	1871	18
1	1871	20
1	1871	22
1	1871	23
1	1871	24
1	1872	1
1	1872	2
1	1872	6
1	1872	8
1	1872	9
1	1872	13
1	1872	14
1	1872	15
1	1872	17
1	1872	19
1	1872	20
1	1872	21
1	1872	22
1	1872	23
1	1872	25
1	1873	1
1	1873	4
1	1873	5
1	1873	7
1	1873	8
1	1873	9
1	1873	10
1	1873	11
1	1873	12
1	1873	14
1	1873	15
1	1873	17
1	1873	19
1	1873	21
1	1873	23
1	1874	1
1	1874	5
1	1874	6
1	1874	8
1	1874	9
1	1874	10
1	1874	13
1	1874	14
1	1874	17
1	1874	19
1	1874	20
1	1874	21
1	1874	22
1	1874	24
1	1874	25
1	1875	1
1	1875	3
1	1875	4
1	1875	5
1	1875	7
1	1875	8
1	1875	13
1	1875	14
1	1875	16
1	1875	18
1	1875	19
1	1875	21
1	1875	22
1	1875	23
1	1875	24
1	1876	1
1	1876	2
1	1876	3
1	1876	4
1	1876	7
1	1876	8
1	1876	11
1	1876	13
1	1876	16
1	1876	18
1	1876	19
1	1876	20
1	1876	22
1	1876	23
1	1876	24
1	1877	2
1	1877	4
1	1877	8
1	1877	9
1	1877	11
1	1877	12
1	1877	13
1	1877	14
1	1877	15
1	1877	18
1	1877	19
1	1877	21
1	1877	23
1	1877	24
1	1877	25
1	1878	1
1	1878	2
1	1878	3
1	1878	4
1	1878	5
1	1878	6
1	1878	8
1	1878	10
1	1878	12
1	1878	15
1	1878	17
1	1878	19
1	1878	23
1	1878	24
1	1878	25
1	1879	2
1	1879	4
1	1879	5
1	1879	6
1	1879	8
1	1879	10
1	1879	11
1	1879	13
1	1879	15
1	1879	16
1	1879	19
1	1879	20
1	1879	21
1	1879	24
1	1879	25
1	1880	1
1	1880	4
1	1880	5
1	1880	6
1	1880	7
1	1880	9
1	1880	11
1	1880	13
1	1880	15
1	1880	18
1	1880	19
1	1880	20
1	1880	22
1	1880	23
1	1880	24
1	1881	1
1	1881	3
1	1881	4
1	1881	5
1	1881	10
1	1881	14
1	1881	15
1	1881	16
1	1881	17
1	1881	18
1	1881	19
1	1881	21
1	1881	23
1	1881	24
1	1881	25
1	1882	1
1	1882	3
1	1882	4
1	1882	5
1	1882	8
1	1882	9
1	1882	11
1	1882	12
1	1882	13
1	1882	14
1	1882	15
1	1882	16
1	1882	22
1	1882	23
1	1882	24
1	1883	1
1	1883	2
1	1883	3
1	1883	4
1	1883	5
1	1883	8
1	1883	11
1	1883	13
1	1883	15
1	1883	16
1	1883	17
1	1883	18
1	1883	21
1	1883	22
1	1883	23
1	1884	1
1	1884	2
1	1884	3
1	1884	5
1	1884	6
1	1884	7
1	1884	8
1	1884	9
1	1884	11
1	1884	12
1	1884	14
1	1884	16
1	1884	17
1	1884	23
1	1884	25
1	1885	1
1	1885	3
1	1885	5
1	1885	8
1	1885	9
1	1885	10
1	1885	11
1	1885	12
1	1885	14
1	1885	17
1	1885	18
1	1885	21
1	1885	22
1	1885	23
1	1885	25
1	1886	1
1	1886	2
1	1886	3
1	1886	6
1	1886	9
1	1886	11
1	1886	12
1	1886	14
1	1886	15
1	1886	16
1	1886	19
1	1886	20
1	1886	21
1	1886	22
1	1886	25
1	1887	1
1	1887	3
1	1887	4
1	1887	6
1	1887	7
1	1887	8
1	1887	9
1	1887	10
1	1887	11
1	1887	12
1	1887	14
1	1887	16
1	1887	17
1	1887	18
1	1887	22
1	1888	2
1	1888	4
1	1888	6
1	1888	7
1	1888	8
1	1888	11
1	1888	12
1	1888	14
1	1888	17
1	1888	18
1	1888	20
1	1888	22
1	1888	23
1	1888	24
1	1888	25
1	1889	1
1	1889	2
1	1889	4
1	1889	6
1	1889	7
1	1889	11
1	1889	13
1	1889	14
1	1889	15
1	1889	19
1	1889	20
1	1889	22
1	1889	23
1	1889	24
1	1889	25
1	1890	1
1	1890	2
1	1890	4
1	1890	5
1	1890	7
1	1890	8
1	1890	9
1	1890	10
1	1890	11
1	1890	13
1	1890	15
1	1890	16
1	1890	17
1	1890	21
1	1890	23
1	1891	3
1	1891	4
1	1891	6
1	1891	7
1	1891	11
1	1891	14
1	1891	15
1	1891	16
1	1891	19
1	1891	20
1	1891	21
1	1891	22
1	1891	23
1	1891	24
1	1891	25
1	1892	1
1	1892	3
1	1892	5
1	1892	6
1	1892	7
1	1892	8
1	1892	9
1	1892	10
1	1892	11
1	1892	19
1	1892	20
1	1892	21
1	1892	23
1	1892	24
1	1892	25
1	1893	2
1	1893	3
1	1893	4
1	1893	5
1	1893	7
1	1893	9
1	1893	10
1	1893	14
1	1893	15
1	1893	16
1	1893	19
1	1893	20
1	1893	21
1	1893	22
1	1893	25
1	1894	2
1	1894	4
1	1894	5
1	1894	8
1	1894	9
1	1894	11
1	1894	12
1	1894	15
1	1894	16
1	1894	17
1	1894	18
1	1894	19
1	1894	21
1	1894	22
1	1894	25
1	1895	1
1	1895	2
1	1895	3
1	1895	4
1	1895	6
1	1895	8
1	1895	9
1	1895	10
1	1895	13
1	1895	14
1	1895	19
1	1895	22
1	1895	23
1	1895	24
1	1895	25
1	1896	1
1	1896	2
1	1896	3
1	1896	6
1	1896	8
1	1896	9
1	1896	12
1	1896	15
1	1896	16
1	1896	17
1	1896	18
1	1896	20
1	1896	21
1	1896	22
1	1896	24
1	1897	1
1	1897	3
1	1897	4
1	1897	5
1	1897	7
1	1897	8
1	1897	12
1	1897	13
1	1897	14
1	1897	15
1	1897	16
1	1897	17
1	1897	20
1	1897	21
1	1897	24
1	1898	5
1	1898	6
1	1898	8
1	1898	9
1	1898	10
1	1898	12
1	1898	13
1	1898	14
1	1898	16
1	1898	18
1	1898	19
1	1898	20
1	1898	21
1	1898	22
1	1898	23
1	1899	1
1	1899	3
1	1899	5
1	1899	6
1	1899	9
1	1899	10
1	1899	11
1	1899	14
1	1899	15
1	1899	16
1	1899	17
1	1899	18
1	1899	19
1	1899	20
1	1899	23
1	1900	1
1	1900	5
1	1900	6
1	1900	7
1	1900	8
1	1900	10
1	1900	11
1	1900	12
1	1900	13
1	1900	16
1	1900	17
1	1900	18
1	1900	19
1	1900	22
1	1900	25
1	1901	2
1	1901	3
1	1901	4
1	1901	5
1	1901	9
1	1901	10
1	1901	12
1	1901	13
1	1901	14
1	1901	15
1	1901	16
1	1901	17
1	1901	18
1	1901	19
1	1901	20
1	1902	1
1	1902	2
1	1902	4
1	1902	5
1	1902	6
1	1902	8
1	1902	9
1	1902	11
1	1902	12
1	1902	15
1	1902	16
1	1902	17
1	1902	22
1	1902	23
1	1902	25
1	1903	4
1	1903	6
1	1903	7
1	1903	8
1	1903	9
1	1903	10
1	1903	12
1	1903	14
1	1903	15
1	1903	16
1	1903	19
1	1903	20
1	1903	21
1	1903	23
1	1903	24
1	1904	1
1	1904	6
1	1904	7
1	1904	8
1	1904	10
1	1904	11
1	1904	12
1	1904	13
1	1904	14
1	1904	15
1	1904	17
1	1904	18
1	1904	20
1	1904	23
1	1904	25
1	1905	1
1	1905	3
1	1905	6
1	1905	8
1	1905	9
1	1905	11
1	1905	12
1	1905	15
1	1905	16
1	1905	17
1	1905	18
1	1905	19
1	1905	21
1	1905	23
1	1905	24
1	1906	1
1	1906	2
1	1906	3
1	1906	4
1	1906	6
1	1906	7
1	1906	10
1	1906	11
1	1906	14
1	1906	16
1	1906	17
1	1906	18
1	1906	23
1	1906	24
1	1906	25
1	1907	1
1	1907	3
1	1907	4
1	1907	5
1	1907	9
1	1907	10
1	1907	13
1	1907	15
1	1907	16
1	1907	17
1	1907	19
1	1907	21
1	1907	23
1	1907	24
1	1907	25
1	1908	2
1	1908	4
1	1908	6
1	1908	7
1	1908	8
1	1908	12
1	1908	13
1	1908	14
1	1908	16
1	1908	17
1	1908	20
1	1908	22
1	1908	23
1	1908	24
1	1908	25
1	1909	2
1	1909	3
1	1909	4
1	1909	5
1	1909	6
1	1909	8
1	1909	9
1	1909	10
1	1909	11
1	1909	12
1	1909	14
1	1909	17
1	1909	18
1	1909	22
1	1909	25
1	1910	2
1	1910	3
1	1910	4
1	1910	7
1	1910	9
1	1910	10
1	1910	12
1	1910	13
1	1910	14
1	1910	15
1	1910	16
1	1910	18
1	1910	22
1	1910	23
1	1910	25
1	1911	1
1	1911	2
1	1911	4
1	1911	5
1	1911	8
1	1911	11
1	1911	12
1	1911	13
1	1911	14
1	1911	15
1	1911	19
1	1911	21
1	1911	22
1	1911	24
1	1911	25
1	1912	2
1	1912	5
1	1912	6
1	1912	7
1	1912	8
1	1912	9
1	1912	10
1	1912	14
1	1912	16
1	1912	18
1	1912	20
1	1912	21
1	1912	22
1	1912	23
1	1912	24
1	1913	2
1	1913	5
1	1913	6
1	1913	7
1	1913	8
1	1913	9
1	1913	10
1	1913	11
1	1913	12
1	1913	14
1	1913	16
1	1913	19
1	1913	20
1	1913	24
1	1913	25
1	1914	2
1	1914	4
1	1914	5
1	1914	8
1	1914	10
1	1914	12
1	1914	13
1	1914	14
1	1914	15
1	1914	17
1	1914	18
1	1914	19
1	1914	20
1	1914	21
1	1914	25
1	1915	2
1	1915	4
1	1915	8
1	1915	10
1	1915	11
1	1915	12
1	1915	13
1	1915	15
1	1915	16
1	1915	17
1	1915	19
1	1915	20
1	1915	21
1	1915	22
1	1915	25
1	1916	4
1	1916	5
1	1916	6
1	1916	7
1	1916	8
1	1916	10
1	1916	11
1	1916	13
1	1916	15
1	1916	18
1	1916	19
1	1916	20
1	1916	23
1	1916	24
1	1916	25
1	1917	1
1	1917	2
1	1917	3
1	1917	4
1	1917	10
1	1917	13
1	1917	14
1	1917	15
1	1917	17
1	1917	19
1	1917	20
1	1917	21
1	1917	23
1	1917	24
1	1917	25
1	1918	2
1	1918	4
1	1918	5
1	1918	6
1	1918	7
1	1918	9
1	1918	10
1	1918	11
1	1918	12
1	1918	17
1	1918	18
1	1918	19
1	1918	20
1	1918	22
1	1918	24
1	1919	1
1	1919	2
1	1919	3
1	1919	5
1	1919	6
1	1919	9
1	1919	10
1	1919	11
1	1919	15
1	1919	19
1	1919	20
1	1919	21
1	1919	22
1	1919	23
1	1919	24
1	1920	2
1	1920	4
1	1920	6
1	1920	9
1	1920	10
1	1920	11
1	1920	12
1	1920	13
1	1920	14
1	1920	17
1	1920	18
1	1920	20
1	1920	21
1	1920	22
1	1920	25
1	1921	2
1	1921	3
1	1921	4
1	1921	5
1	1921	6
1	1921	7
1	1921	8
1	1921	9
1	1921	10
1	1921	13
1	1921	15
1	1921	16
1	1921	18
1	1921	21
1	1921	24
1	1922	2
1	1922	3
1	1922	4
1	1922	5
1	1922	6
1	1922	7
1	1922	8
1	1922	10
1	1922	12
1	1922	16
1	1922	17
1	1922	18
1	1922	19
1	1922	23
1	1922	25
1	1923	1
1	1923	4
1	1923	5
1	1923	7
1	1923	10
1	1923	11
1	1923	12
1	1923	14
1	1923	17
1	1923	19
1	1923	20
1	1923	22
1	1923	23
1	1923	24
1	1923	25
1	1924	2
1	1924	3
1	1924	8
1	1924	9
1	1924	10
1	1924	11
1	1924	12
1	1924	13
1	1924	14
1	1924	17
1	1924	18
1	1924	22
1	1924	23
1	1924	24
1	1924	25
1	1925	1
1	1925	2
1	1925	3
1	1925	4
1	1925	5
1	1925	6
1	1925	7
1	1925	9
1	1925	13
1	1925	14
1	1925	16
1	1925	18
1	1925	20
1	1925	21
1	1925	23
1	1926	1
1	1926	4
1	1926	5
1	1926	6
1	1926	9
1	1926	10
1	1926	13
1	1926	14
1	1926	15
1	1926	16
1	1926	17
1	1926	18
1	1926	21
1	1926	23
1	1926	24
1	1927	1
1	1927	2
1	1927	4
1	1927	5
1	1927	8
1	1927	10
1	1927	11
1	1927	13
1	1927	15
1	1927	17
1	1927	18
1	1927	21
1	1927	22
1	1927	23
1	1927	24
1	1928	1
1	1928	2
1	1928	3
1	1928	5
1	1928	6
1	1928	7
1	1928	8
1	1928	9
1	1928	10
1	1928	15
1	1928	16
1	1928	19
1	1928	23
1	1928	24
1	1928	25
1	1929	1
1	1929	2
1	1929	3
1	1929	4
1	1929	7
1	1929	8
1	1929	9
1	1929	10
1	1929	11
1	1929	13
1	1929	15
1	1929	19
1	1929	20
1	1929	22
1	1929	25
1	1930	1
1	1930	2
1	1930	4
1	1930	5
1	1930	7
1	1930	8
1	1930	10
1	1930	13
1	1930	14
1	1930	16
1	1930	17
1	1930	21
1	1930	22
1	1930	23
1	1930	24
1	1931	3
1	1931	4
1	1931	5
1	1931	6
1	1931	7
1	1931	9
1	1931	10
1	1931	11
1	1931	12
1	1931	14
1	1931	16
1	1931	18
1	1931	19
1	1931	22
1	1931	23
1	1932	2
1	1932	4
1	1932	6
1	1932	8
1	1932	9
1	1932	10
1	1932	11
1	1932	12
1	1932	14
1	1932	16
1	1932	17
1	1932	19
1	1932	20
1	1932	22
1	1932	24
1	1933	1
1	1933	7
1	1933	9
1	1933	10
1	1933	11
1	1933	12
1	1933	13
1	1933	16
1	1933	19
1	1933	20
1	1933	21
1	1933	22
1	1933	23
1	1933	24
1	1933	25
1	1934	1
1	1934	2
1	1934	3
1	1934	4
1	1934	5
1	1934	7
1	1934	8
1	1934	9
1	1934	10
1	1934	11
1	1934	12
1	1934	20
1	1934	23
1	1934	24
1	1934	25
1	1935	1
1	1935	3
1	1935	5
1	1935	6
1	1935	7
1	1935	8
1	1935	10
1	1935	12
1	1935	15
1	1935	16
1	1935	17
1	1935	18
1	1935	22
1	1935	23
1	1935	24
1	1936	2
1	1936	3
1	1936	4
1	1936	5
1	1936	6
1	1936	8
1	1936	11
1	1936	13
1	1936	14
1	1936	15
1	1936	17
1	1936	19
1	1936	20
1	1936	21
1	1936	25
1	1937	3
1	1937	4
1	1937	5
1	1937	6
1	1937	9
1	1937	10
1	1937	11
1	1937	12
1	1937	15
1	1937	17
1	1937	19
1	1937	21
1	1937	22
1	1937	23
1	1937	24
1	1938	3
1	1938	4
1	1938	6
1	1938	7
1	1938	8
1	1938	10
1	1938	11
1	1938	12
1	1938	16
1	1938	18
1	1938	19
1	1938	20
1	1938	21
1	1938	22
1	1938	25
1	1939	2
1	1939	3
1	1939	4
1	1939	6
1	1939	7
1	1939	9
1	1939	10
1	1939	11
1	1939	12
1	1939	13
1	1939	19
1	1939	20
1	1939	22
1	1939	23
1	1939	24
1	1940	1
1	1940	5
1	1940	8
1	1940	10
1	1940	11
1	1940	12
1	1940	13
1	1940	15
1	1940	17
1	1940	18
1	1940	21
1	1940	22
1	1940	23
1	1940	24
1	1940	25
1	1941	1
1	1941	3
1	1941	4
1	1941	5
1	1941	8
1	1941	10
1	1941	12
1	1941	13
1	1941	14
1	1941	16
1	1941	17
1	1941	20
1	1941	22
1	1941	24
1	1941	25
1	1942	1
1	1942	2
1	1942	3
1	1942	4
1	1942	7
1	1942	8
1	1942	10
1	1942	11
1	1942	12
1	1942	13
1	1942	15
1	1942	18
1	1942	20
1	1942	24
1	1942	25
1	1943	2
1	1943	3
1	1943	6
1	1943	9
1	1943	10
1	1943	13
1	1943	14
1	1943	15
1	1943	16
1	1943	17
1	1943	18
1	1943	19
1	1943	20
1	1943	22
1	1943	23
1	1944	1
1	1944	2
1	1944	4
1	1944	5
1	1944	7
1	1944	8
1	1944	9
1	1944	10
1	1944	11
1	1944	13
1	1944	16
1	1944	18
1	1944	22
1	1944	23
1	1944	24
1	1945	3
1	1945	4
1	1945	5
1	1945	8
1	1945	9
1	1945	10
1	1945	12
1	1945	15
1	1945	17
1	1945	19
1	1945	20
1	1945	22
1	1945	23
1	1945	24
1	1945	25
1	1946	1
1	1946	2
1	1946	3
1	1946	4
1	1946	6
1	1946	7
1	1946	10
1	1946	11
1	1946	13
1	1946	14
1	1946	15
1	1946	20
1	1946	21
1	1946	22
1	1946	23
1	1947	2
1	1947	5
1	1947	6
1	1947	9
1	1947	11
1	1947	13
1	1947	14
1	1947	15
1	1947	16
1	1947	18
1	1947	19
1	1947	22
1	1947	23
1	1947	24
1	1947	25
1	1948	1
1	1948	3
1	1948	7
1	1948	9
1	1948	11
1	1948	12
1	1948	13
1	1948	14
1	1948	16
1	1948	17
1	1948	19
1	1948	20
1	1948	21
1	1948	22
1	1948	24
1	1949	2
1	1949	3
1	1949	5
1	1949	6
1	1949	8
1	1949	10
1	1949	11
1	1949	14
1	1949	15
1	1949	16
1	1949	19
1	1949	20
1	1949	22
1	1949	23
1	1949	25
1	1950	2
1	1950	3
1	1950	4
1	1950	6
1	1950	8
1	1950	9
1	1950	10
1	1950	11
1	1950	12
1	1950	16
1	1950	18
1	1950	20
1	1950	21
1	1950	23
1	1950	25
1	1951	3
1	1951	4
1	1951	6
1	1951	9
1	1951	10
1	1951	11
1	1951	12
1	1951	13
1	1951	16
1	1951	18
1	1951	19
1	1951	20
1	1951	22
1	1951	23
1	1951	25
1	1952	3
1	1952	5
1	1952	7
1	1952	9
1	1952	10
1	1952	11
1	1952	13
1	1952	14
1	1952	16
1	1952	17
1	1952	18
1	1952	20
1	1952	21
1	1952	22
1	1952	24
1	1953	1
1	1953	3
1	1953	4
1	1953	5
1	1953	6
1	1953	9
1	1953	10
1	1953	15
1	1953	16
1	1953	18
1	1953	19
1	1953	20
1	1953	21
1	1953	22
1	1953	23
1	1954	2
1	1954	3
1	1954	4
1	1954	6
1	1954	7
1	1954	8
1	1954	10
1	1954	13
1	1954	16
1	1954	18
1	1954	21
1	1954	22
1	1954	23
1	1954	24
1	1954	25
1	1955	1
1	1955	2
1	1955	4
1	1955	5
1	1955	9
1	1955	12
1	1955	14
1	1955	15
1	1955	16
1	1955	19
1	1955	20
1	1955	22
1	1955	23
1	1955	24
1	1955	25
1	1956	3
1	1956	4
1	1956	6
1	1956	7
1	1956	8
1	1956	9
1	1956	10
1	1956	14
1	1956	15
1	1956	16
1	1956	19
1	1956	20
1	1956	21
1	1956	22
1	1956	23
1	1957	1
1	1957	2
1	1957	3
1	1957	4
1	1957	5
1	1957	7
1	1957	11
1	1957	14
1	1957	15
1	1957	16
1	1957	17
1	1957	19
1	1957	20
1	1957	23
1	1957	25
1	1958	2
1	1958	3
1	1958	5
1	1958	6
1	1958	7
1	1958	8
1	1958	11
1	1958	15
1	1958	17
1	1958	18
1	1958	20
1	1958	21
1	1958	22
1	1958	23
1	1958	25
1	1959	1
1	1959	2
1	1959	3
1	1959	6
1	1959	7
1	1959	9
1	1959	10
1	1959	12
1	1959	13
1	1959	16
1	1959	17
1	1959	18
1	1959	20
1	1959	24
1	1959	25
1	1960	2
1	1960	3
1	1960	7
1	1960	9
1	1960	10
1	1960	12
1	1960	13
1	1960	15
1	1960	17
1	1960	18
1	1960	20
1	1960	21
1	1960	23
1	1960	24
1	1960	25
1	1961	2
1	1961	4
1	1961	5
1	1961	7
1	1961	12
1	1961	13
1	1961	14
1	1961	15
1	1961	18
1	1961	19
1	1961	20
1	1961	21
1	1961	22
1	1961	23
1	1961	24
1	1962	1
1	1962	2
1	1962	3
1	1962	4
1	1962	6
1	1962	9
1	1962	12
1	1962	13
1	1962	14
1	1962	15
1	1962	16
1	1962	19
1	1962	20
1	1962	21
1	1962	22
1	1963	3
1	1963	4
1	1963	5
1	1963	8
1	1963	9
1	1963	10
1	1963	11
1	1963	12
1	1963	13
1	1963	14
1	1963	15
1	1963	18
1	1963	20
1	1963	24
1	1963	25
1	1964	1
1	1964	2
1	1964	3
1	1964	5
1	1964	8
1	1964	9
1	1964	10
1	1964	12
1	1964	13
1	1964	14
1	1964	15
1	1964	16
1	1964	17
1	1964	19
1	1964	23
1	1965	1
1	1965	2
1	1965	4
1	1965	5
1	1965	6
1	1965	10
1	1965	12
1	1965	16
1	1965	19
1	1965	20
1	1965	21
1	1965	22
1	1965	23
1	1965	24
1	1965	25
1	1966	1
1	1966	3
1	1966	4
1	1966	5
1	1966	6
1	1966	7
1	1966	9
1	1966	12
1	1966	13
1	1966	14
1	1966	15
1	1966	16
1	1966	18
1	1966	19
1	1966	24
1	1967	1
1	1967	2
1	1967	3
1	1967	5
1	1967	7
1	1967	8
1	1967	10
1	1967	11
1	1967	12
1	1967	13
1	1967	14
1	1967	15
1	1967	17
1	1967	23
1	1967	24
1	1968	1
1	1968	2
1	1968	3
1	1968	4
1	1968	5
1	1968	7
1	1968	9
1	1968	13
1	1968	14
1	1968	16
1	1968	18
1	1968	20
1	1968	22
1	1968	23
1	1968	25
1	1969	4
1	1969	5
1	1969	6
1	1969	7
1	1969	9
1	1969	13
1	1969	14
1	1969	15
1	1969	16
1	1969	18
1	1969	19
1	1969	20
1	1969	22
1	1969	23
1	1969	24
1	1970	3
1	1970	6
1	1970	8
1	1970	9
1	1970	10
1	1970	11
1	1970	12
1	1970	13
1	1970	14
1	1970	16
1	1970	17
1	1970	20
1	1970	21
1	1970	24
1	1970	25
1	1971	3
1	1971	6
1	1971	8
1	1971	9
1	1971	10
1	1971	13
1	1971	14
1	1971	15
1	1971	16
1	1971	17
1	1971	18
1	1971	19
1	1971	21
1	1971	23
1	1971	25
1	1972	3
1	1972	7
1	1972	8
1	1972	11
1	1972	12
1	1972	13
1	1972	14
1	1972	15
1	1972	16
1	1972	18
1	1972	20
1	1972	21
1	1972	22
1	1972	23
1	1972	25
1	1973	2
1	1973	3
1	1973	6
1	1973	7
1	1973	8
1	1973	9
1	1973	10
1	1973	13
1	1973	14
1	1973	16
1	1973	17
1	1973	18
1	1973	19
1	1973	23
1	1973	25
1	1974	1
1	1974	2
1	1974	4
1	1974	5
1	1974	6
1	1974	9
1	1974	10
1	1974	11
1	1974	12
1	1974	16
1	1974	20
1	1974	21
1	1974	23
1	1974	24
1	1974	25
1	1975	2
1	1975	5
1	1975	7
1	1975	8
1	1975	9
1	1975	10
1	1975	11
1	1975	12
1	1975	13
1	1975	16
1	1975	17
1	1975	20
1	1975	22
1	1975	23
1	1975	25
1	1976	1
1	1976	3
1	1976	7
1	1976	9
1	1976	10
1	1976	11
1	1976	13
1	1976	14
1	1976	15
1	1976	17
1	1976	18
1	1976	19
1	1976	20
1	1976	22
1	1976	24
1	1977	1
1	1977	3
1	1977	4
1	1977	5
1	1977	7
1	1977	10
1	1977	12
1	1977	13
1	1977	15
1	1977	16
1	1977	17
1	1977	18
1	1977	19
1	1977	22
1	1977	23
1	1978	1
1	1978	4
1	1978	5
1	1978	6
1	1978	7
1	1978	8
1	1978	9
1	1978	10
1	1978	12
1	1978	13
1	1978	15
1	1978	16
1	1978	20
1	1978	23
1	1978	24
1	1979	4
1	1979	5
1	1979	6
1	1979	9
1	1979	10
1	1979	11
1	1979	12
1	1979	13
1	1979	14
1	1979	15
1	1979	16
1	1979	18
1	1979	21
1	1979	22
1	1979	25
1	1980	3
1	1980	4
1	1980	5
1	1980	7
1	1980	9
1	1980	10
1	1980	13
1	1980	16
1	1980	17
1	1980	18
1	1980	19
1	1980	21
1	1980	22
1	1980	23
1	1980	24
1	1981	1
1	1981	2
1	1981	3
1	1981	4
1	1981	5
1	1981	6
1	1981	7
1	1981	12
1	1981	13
1	1981	15
1	1981	17
1	1981	20
1	1981	23
1	1981	24
1	1981	25
1	1982	1
1	1982	2
1	1982	3
1	1982	4
1	1982	5
1	1982	7
1	1982	14
1	1982	15
1	1982	16
1	1982	17
1	1982	18
1	1982	19
1	1982	20
1	1982	22
1	1982	25
1	1983	1
1	1983	2
1	1983	5
1	1983	6
1	1983	7
1	1983	8
1	1983	9
1	1983	10
1	1983	11
1	1983	12
1	1983	16
1	1983	19
1	1983	20
1	1983	23
1	1983	24
1	1984	2
1	1984	4
1	1984	5
1	1984	10
1	1984	11
1	1984	12
1	1984	13
1	1984	14
1	1984	16
1	1984	19
1	1984	20
1	1984	21
1	1984	23
1	1984	24
1	1984	25
1	1985	1
1	1985	2
1	1985	3
1	1985	6
1	1985	7
1	1985	9
1	1985	11
1	1985	12
1	1985	14
1	1985	15
1	1985	17
1	1985	21
1	1985	22
1	1985	23
1	1985	24
1	1986	1
1	1986	4
1	1986	5
1	1986	7
1	1986	8
1	1986	10
1	1986	11
1	1986	12
1	1986	13
1	1986	15
1	1986	17
1	1986	18
1	1986	21
1	1986	23
1	1986	24
1	1987	2
1	1987	3
1	1987	4
1	1987	5
1	1987	6
1	1987	10
1	1987	11
1	1987	12
1	1987	13
1	1987	15
1	1987	16
1	1987	17
1	1987	19
1	1987	21
1	1987	22
1	1988	2
1	1988	5
1	1988	6
1	1988	7
1	1988	9
1	1988	11
1	1988	12
1	1988	14
1	1988	15
1	1988	17
1	1988	19
1	1988	21
1	1988	22
1	1988	23
1	1988	24
1	1989	1
1	1989	2
1	1989	4
1	1989	6
1	1989	7
1	1989	9
1	1989	10
1	1989	11
1	1989	12
1	1989	16
1	1989	17
1	1989	19
1	1989	23
1	1989	24
1	1989	25
1	1990	4
1	1990	6
1	1990	7
1	1990	8
1	1990	9
1	1990	11
1	1990	13
1	1990	14
1	1990	16
1	1990	17
1	1990	19
1	1990	20
1	1990	23
1	1990	24
1	1990	25
1	1991	1
1	1991	2
1	1991	5
1	1991	6
1	1991	7
1	1991	8
1	1991	10
1	1991	14
1	1991	15
1	1991	16
1	1991	17
1	1991	18
1	1991	20
1	1991	22
1	1991	24
1	1992	3
1	1992	4
1	1992	5
1	1992	6
1	1992	7
1	1992	8
1	1992	9
1	1992	11
1	1992	12
1	1992	14
1	1992	19
1	1992	20
1	1992	21
1	1992	22
1	1992	23
1	1993	1
1	1993	3
1	1993	4
1	1993	5
1	1993	6
1	1993	8
1	1993	9
1	1993	10
1	1993	13
1	1993	15
1	1993	16
1	1993	20
1	1993	21
1	1993	22
1	1993	23
1	1994	3
1	1994	4
1	1994	5
1	1994	6
1	1994	7
1	1994	8
1	1994	9
1	1994	11
1	1994	12
1	1994	17
1	1994	19
1	1994	20
1	1994	22
1	1994	24
1	1994	25
1	1995	1
1	1995	3
1	1995	5
1	1995	7
1	1995	9
1	1995	10
1	1995	11
1	1995	12
1	1995	13
1	1995	14
1	1995	18
1	1995	19
1	1995	20
1	1995	23
1	1995	25
1	1996	2
1	1996	4
1	1996	5
1	1996	7
1	1996	8
1	1996	9
1	1996	10
1	1996	11
1	1996	12
1	1996	13
1	1996	18
1	1996	19
1	1996	20
1	1996	22
1	1996	25
1	1997	2
1	1997	4
1	1997	6
1	1997	7
1	1997	8
1	1997	9
1	1997	12
1	1997	13
1	1997	14
1	1997	15
1	1997	16
1	1997	18
1	1997	20
1	1997	21
1	1997	22
1	1998	1
1	1998	3
1	1998	4
1	1998	5
1	1998	6
1	1998	10
1	1998	11
1	1998	12
1	1998	13
1	1998	14
1	1998	17
1	1998	19
1	1998	20
1	1998	22
1	1998	24
1	1999	3
1	1999	4
1	1999	6
1	1999	7
1	1999	8
1	1999	9
1	1999	13
1	1999	15
1	1999	17
1	1999	19
1	1999	20
1	1999	22
1	1999	23
1	1999	24
1	1999	25
1	2000	2
1	2000	3
1	2000	4
1	2000	7
1	2000	11
1	2000	12
1	2000	14
1	2000	16
1	2000	17
1	2000	18
1	2000	19
1	2000	20
1	2000	22
1	2000	23
1	2000	24
1	2001	1
1	2001	2
1	2001	3
1	2001	6
1	2001	7
1	2001	9
1	2001	10
1	2001	11
1	2001	16
1	2001	17
1	2001	19
1	2001	20
1	2001	21
1	2001	22
1	2001	25
1	2002	2
1	2002	3
1	2002	5
1	2002	8
1	2002	10
1	2002	12
1	2002	13
1	2002	14
1	2002	16
1	2002	17
1	2002	18
1	2002	19
1	2002	20
1	2002	24
1	2002	25
1	2003	1
1	2003	5
1	2003	6
1	2003	7
1	2003	8
1	2003	9
1	2003	10
1	2003	11
1	2003	12
1	2003	15
1	2003	17
1	2003	20
1	2003	22
1	2003	24
1	2003	25
1	2004	1
1	2004	3
1	2004	4
1	2004	8
1	2004	10
1	2004	11
1	2004	12
1	2004	13
1	2004	14
1	2004	15
1	2004	18
1	2004	19
1	2004	21
1	2004	22
1	2004	25
1	2005	3
1	2005	6
1	2005	8
1	2005	9
1	2005	11
1	2005	12
1	2005	13
1	2005	15
1	2005	17
1	2005	18
1	2005	19
1	2005	21
1	2005	22
1	2005	24
1	2005	25
1	2006	1
1	2006	2
1	2006	4
1	2006	5
1	2006	7
1	2006	8
1	2006	10
1	2006	13
1	2006	17
1	2006	19
1	2006	20
1	2006	21
1	2006	23
1	2006	24
1	2006	25
1	2007	1
1	2007	3
1	2007	5
1	2007	6
1	2007	10
1	2007	11
1	2007	15
1	2007	16
1	2007	17
1	2007	18
1	2007	19
1	2007	20
1	2007	21
1	2007	22
1	2007	24
1	2008	2
1	2008	3
1	2008	5
1	2008	6
1	2008	8
1	2008	10
1	2008	11
1	2008	12
1	2008	13
1	2008	14
1	2008	15
1	2008	17
1	2008	21
1	2008	23
1	2008	25
1	2009	1
1	2009	2
1	2009	3
1	2009	4
1	2009	5
1	2009	7
1	2009	12
1	2009	13
1	2009	15
1	2009	16
1	2009	17
1	2009	19
1	2009	20
1	2009	22
1	2009	24
1	2010	2
1	2010	3
1	2010	4
1	2010	5
1	2010	6
1	2010	10
1	2010	11
1	2010	12
1	2010	16
1	2010	19
1	2010	20
1	2010	21
1	2010	22
1	2010	24
1	2010	25
1	2011	1
1	2011	5
1	2011	7
1	2011	10
1	2011	11
1	2011	13
1	2011	16
1	2011	18
1	2011	19
1	2011	20
1	2011	21
1	2011	22
1	2011	23
1	2011	24
1	2011	25
1	2012	1
1	2012	3
1	2012	4
1	2012	6
1	2012	9
1	2012	10
1	2012	12
1	2012	15
1	2012	16
1	2012	17
1	2012	18
1	2012	20
1	2012	22
1	2012	24
1	2012	25
1	2013	1
1	2013	2
1	2013	4
1	2013	7
1	2013	8
1	2013	10
1	2013	11
1	2013	14
1	2013	16
1	2013	19
1	2013	20
1	2013	21
1	2013	23
1	2013	24
1	2013	25
1	2014	3
1	2014	4
1	2014	6
1	2014	7
1	2014	8
1	2014	9
1	2014	10
1	2014	15
1	2014	16
1	2014	17
1	2014	18
1	2014	19
1	2014	22
1	2014	23
1	2014	25
1	2015	2
1	2015	3
1	2015	4
1	2015	5
1	2015	6
1	2015	8
1	2015	9
1	2015	11
1	2015	13
1	2015	15
1	2015	17
1	2015	18
1	2015	20
1	2015	23
1	2015	25
1	2016	2
1	2016	3
1	2016	9
1	2016	10
1	2016	11
1	2016	13
1	2016	14
1	2016	15
1	2016	17
1	2016	18
1	2016	19
1	2016	22
1	2016	23
1	2016	24
1	2016	25
1	2017	1
1	2017	2
1	2017	3
1	2017	4
1	2017	5
1	2017	8
1	2017	13
1	2017	15
1	2017	16
1	2017	19
1	2017	20
1	2017	21
1	2017	22
1	2017	24
1	2017	25
1	2018	1
1	2018	2
1	2018	3
1	2018	4
1	2018	5
1	2018	8
1	2018	11
1	2018	12
1	2018	13
1	2018	14
1	2018	17
1	2018	18
1	2018	20
1	2018	21
1	2018	22
1	2019	1
1	2019	3
1	2019	5
1	2019	6
1	2019	8
1	2019	9
1	2019	10
1	2019	11
1	2019	14
1	2019	17
1	2019	18
1	2019	20
1	2019	23
1	2019	24
1	2019	25
1	2020	2
1	2020	3
1	2020	4
1	2020	5
1	2020	7
1	2020	8
1	2020	9
1	2020	12
1	2020	15
1	2020	16
1	2020	17
1	2020	19
1	2020	20
1	2020	21
1	2020	25
1	2021	1
1	2021	2
1	2021	3
1	2021	4
1	2021	6
1	2021	7
1	2021	8
1	2021	10
1	2021	12
1	2021	15
1	2021	18
1	2021	19
1	2021	22
1	2021	23
1	2021	24
1	2022	1
1	2022	3
1	2022	6
1	2022	8
1	2022	9
1	2022	10
1	2022	11
1	2022	12
1	2022	13
1	2022	14
1	2022	17
1	2022	18
1	2022	21
1	2022	22
1	2022	25
1	2023	1
1	2023	2
1	2023	4
1	2023	8
1	2023	10
1	2023	11
1	2023	12
1	2023	14
1	2023	15
1	2023	16
1	2023	17
1	2023	19
1	2023	20
1	2023	21
1	2023	25
1	2024	1
1	2024	2
1	2024	3
1	2024	4
1	2024	5
1	2024	6
1	2024	8
1	2024	9
1	2024	11
1	2024	14
1	2024	17
1	2024	18
1	2024	21
1	2024	23
1	2024	24
1	2025	2
1	2025	3
1	2025	4
1	2025	6
1	2025	8
1	2025	9
1	2025	10
1	2025	12
1	2025	14
1	2025	15
1	2025	16
1	2025	18
1	2025	19
1	2025	20
1	2025	22
1	2026	1
1	2026	3
1	2026	4
1	2026	5
1	2026	6
1	2026	11
1	2026	13
1	2026	14
1	2026	16
1	2026	19
1	2026	20
1	2026	21
1	2026	22
1	2026	23
1	2026	24
1	2027	1
1	2027	2
1	2027	3
1	2027	6
1	2027	7
1	2027	9
1	2027	12
1	2027	13
1	2027	16
1	2027	17
1	2027	20
1	2027	21
1	2027	23
1	2027	24
1	2027	25
1	2028	1
1	2028	2
1	2028	3
1	2028	4
1	2028	5
1	2028	6
1	2028	8
1	2028	9
1	2028	15
1	2028	16
1	2028	18
1	2028	19
1	2028	20
1	2028	23
1	2028	25
1	2029	3
1	2029	4
1	2029	7
1	2029	8
1	2029	10
1	2029	11
1	2029	12
1	2029	13
1	2029	16
1	2029	17
1	2029	19
1	2029	22
1	2029	23
1	2029	24
1	2029	25
1	2030	2
1	2030	3
1	2030	4
1	2030	5
1	2030	6
1	2030	9
1	2030	10
1	2030	12
1	2030	14
1	2030	15
1	2030	17
1	2030	19
1	2030	22
1	2030	23
1	2030	25
1	2031	1
1	2031	2
1	2031	3
1	2031	7
1	2031	8
1	2031	9
1	2031	10
1	2031	12
1	2031	13
1	2031	15
1	2031	18
1	2031	20
1	2031	23
1	2031	24
1	2031	25
1	2032	2
1	2032	4
1	2032	5
1	2032	7
1	2032	8
1	2032	9
1	2032	12
1	2032	13
1	2032	15
1	2032	17
1	2032	18
1	2032	19
1	2032	21
1	2032	22
1	2032	25
1	2033	1
1	2033	2
1	2033	5
1	2033	6
1	2033	10
1	2033	11
1	2033	12
1	2033	13
1	2033	14
1	2033	16
1	2033	17
1	2033	19
1	2033	20
1	2033	21
1	2033	22
1	2034	1
1	2034	3
1	2034	4
1	2034	5
1	2034	7
1	2034	8
1	2034	9
1	2034	11
1	2034	13
1	2034	14
1	2034	16
1	2034	18
1	2034	19
1	2034	22
1	2034	24
1	2035	3
1	2035	8
1	2035	10
1	2035	11
1	2035	12
1	2035	13
1	2035	14
1	2035	16
1	2035	18
1	2035	19
1	2035	20
1	2035	22
1	2035	23
1	2035	24
1	2035	25
1	2036	4
1	2036	5
1	2036	6
1	2036	7
1	2036	8
1	2036	11
1	2036	12
1	2036	13
1	2036	17
1	2036	18
1	2036	19
1	2036	21
1	2036	22
1	2036	23
1	2036	25
1	2037	1
1	2037	2
1	2037	4
1	2037	7
1	2037	8
1	2037	9
1	2037	10
1	2037	11
1	2037	14
1	2037	16
1	2037	18
1	2037	20
1	2037	21
1	2037	22
1	2037	23
1	2038	1
1	2038	3
1	2038	5
1	2038	7
1	2038	10
1	2038	11
1	2038	12
1	2038	14
1	2038	15
1	2038	17
1	2038	18
1	2038	19
1	2038	20
1	2038	24
1	2038	25
1	2039	1
1	2039	2
1	2039	3
1	2039	4
1	2039	5
1	2039	6
1	2039	10
1	2039	11
1	2039	14
1	2039	15
1	2039	19
1	2039	21
1	2039	23
1	2039	24
1	2039	25
1	2040	2
1	2040	3
1	2040	8
1	2040	10
1	2040	11
1	2040	12
1	2040	13
1	2040	14
1	2040	15
1	2040	16
1	2040	20
1	2040	21
1	2040	22
1	2040	23
1	2040	24
1	2041	1
1	2041	2
1	2041	4
1	2041	7
1	2041	9
1	2041	11
1	2041	13
1	2041	14
1	2041	16
1	2041	17
1	2041	19
1	2041	22
1	2041	23
1	2041	24
1	2041	25
1	2042	2
1	2042	3
1	2042	4
1	2042	8
1	2042	9
1	2042	10
1	2042	12
1	2042	14
1	2042	15
1	2042	17
1	2042	18
1	2042	21
1	2042	22
1	2042	24
1	2042	25
1	2043	3
1	2043	5
1	2043	7
1	2043	9
1	2043	12
1	2043	13
1	2043	14
1	2043	15
1	2043	17
1	2043	18
1	2043	19
1	2043	21
1	2043	22
1	2043	23
1	2043	25
1	2044	3
1	2044	5
1	2044	6
1	2044	10
1	2044	11
1	2044	13
1	2044	16
1	2044	17
1	2044	18
1	2044	19
1	2044	20
1	2044	21
1	2044	22
1	2044	24
1	2044	25
1	2045	1
1	2045	3
1	2045	5
1	2045	9
1	2045	12
1	2045	13
1	2045	15
1	2045	16
1	2045	17
1	2045	18
1	2045	19
1	2045	20
1	2045	21
1	2045	24
1	2045	25
1	2046	1
1	2046	3
1	2046	4
1	2046	7
1	2046	10
1	2046	11
1	2046	14
1	2046	15
1	2046	17
1	2046	20
1	2046	21
1	2046	22
1	2046	23
1	2046	24
1	2046	25
1	2047	2
1	2047	3
1	2047	4
1	2047	5
1	2047	7
1	2047	8
1	2047	10
1	2047	11
1	2047	12
1	2047	15
1	2047	16
1	2047	18
1	2047	20
1	2047	21
1	2047	23
1	2048	1
1	2048	3
1	2048	4
1	2048	6
1	2048	7
1	2048	8
1	2048	9
1	2048	12
1	2048	13
1	2048	16
1	2048	19
1	2048	20
1	2048	21
1	2048	22
1	2048	25
1	2049	3
1	2049	4
1	2049	8
1	2049	9
1	2049	10
1	2049	11
1	2049	13
1	2049	14
1	2049	16
1	2049	17
1	2049	20
1	2049	21
1	2049	22
1	2049	24
1	2049	25
1	2050	1
1	2050	2
1	2050	3
1	2050	4
1	2050	5
1	2050	6
1	2050	7
1	2050	9
1	2050	13
1	2050	15
1	2050	17
1	2050	18
1	2050	19
1	2050	21
1	2050	22
1	2051	1
1	2051	2
1	2051	3
1	2051	4
1	2051	7
1	2051	9
1	2051	10
1	2051	12
1	2051	16
1	2051	18
1	2051	19
1	2051	20
1	2051	22
1	2051	23
1	2051	25
1	2052	1
1	2052	3
1	2052	4
1	2052	6
1	2052	8
1	2052	10
1	2052	12
1	2052	13
1	2052	14
1	2052	16
1	2052	17
1	2052	18
1	2052	20
1	2052	24
1	2052	25
1	2053	3
1	2053	4
1	2053	9
1	2053	11
1	2053	12
1	2053	13
1	2053	15
1	2053	16
1	2053	17
1	2053	18
1	2053	20
1	2053	21
1	2053	22
1	2053	23
1	2053	24
1	2054	1
1	2054	2
1	2054	3
1	2054	5
1	2054	7
1	2054	8
1	2054	10
1	2054	11
1	2054	12
1	2054	14
1	2054	17
1	2054	19
1	2054	21
1	2054	22
1	2054	23
1	2055	1
1	2055	2
1	2055	3
1	2055	4
1	2055	5
1	2055	7
1	2055	11
1	2055	14
1	2055	15
1	2055	16
1	2055	18
1	2055	19
1	2055	21
1	2055	23
1	2055	25
1	2056	1
1	2056	3
1	2056	4
1	2056	5
1	2056	6
1	2056	9
1	2056	10
1	2056	13
1	2056	15
1	2056	16
1	2056	17
1	2056	18
1	2056	19
1	2056	20
1	2056	21
1	2057	2
1	2057	5
1	2057	6
1	2057	8
1	2057	9
1	2057	10
1	2057	11
1	2057	12
1	2057	13
1	2057	14
1	2057	15
1	2057	16
1	2057	18
1	2057	20
1	2057	25
1	2058	1
1	2058	5
1	2058	7
1	2058	8
1	2058	10
1	2058	12
1	2058	13
1	2058	14
1	2058	15
1	2058	17
1	2058	20
1	2058	21
1	2058	22
1	2058	23
1	2058	24
1	2059	1
1	2059	4
1	2059	5
1	2059	10
1	2059	12
1	2059	14
1	2059	15
1	2059	16
1	2059	17
1	2059	18
1	2059	19
1	2059	20
1	2059	21
1	2059	23
1	2059	25
1	2060	3
1	2060	5
1	2060	9
1	2060	13
1	2060	14
1	2060	16
1	2060	17
1	2060	18
1	2060	19
1	2060	20
1	2060	21
1	2060	22
1	2060	23
1	2060	24
1	2060	25
1	2061	1
1	2061	2
1	2061	5
1	2061	8
1	2061	10
1	2061	11
1	2061	12
1	2061	15
1	2061	16
1	2061	17
1	2061	18
1	2061	19
1	2061	20
1	2061	21
1	2061	23
1	2062	3
1	2062	4
1	2062	6
1	2062	7
1	2062	8
1	2062	9
1	2062	10
1	2062	12
1	2062	14
1	2062	15
1	2062	19
1	2062	20
1	2062	22
1	2062	23
1	2062	24
1	2063	1
1	2063	2
1	2063	5
1	2063	6
1	2063	7
1	2063	10
1	2063	11
1	2063	13
1	2063	16
1	2063	18
1	2063	19
1	2063	20
1	2063	22
1	2063	24
1	2063	25
1	2064	6
1	2064	7
1	2064	9
1	2064	10
1	2064	11
1	2064	12
1	2064	13
1	2064	17
1	2064	18
1	2064	19
1	2064	20
1	2064	21
1	2064	22
1	2064	24
1	2064	25
1	2065	4
1	2065	5
1	2065	6
1	2065	7
1	2065	8
1	2065	9
1	2065	10
1	2065	11
1	2065	12
1	2065	13
1	2065	14
1	2065	17
1	2065	19
1	2065	21
1	2065	22
1	2066	2
1	2066	4
1	2066	6
1	2066	8
1	2066	9
1	2066	10
1	2066	12
1	2066	14
1	2066	15
1	2066	16
1	2066	17
1	2066	18
1	2066	19
1	2066	24
1	2066	25
1	2067	1
1	2067	7
1	2067	8
1	2067	9
1	2067	12
1	2067	13
1	2067	14
1	2067	16
1	2067	17
1	2067	19
1	2067	20
1	2067	21
1	2067	23
1	2067	24
1	2067	25
1	2068	1
1	2068	2
1	2068	3
1	2068	7
1	2068	10
1	2068	14
1	2068	15
1	2068	16
1	2068	18
1	2068	19
1	2068	20
1	2068	21
1	2068	23
1	2068	24
1	2068	25
1	2069	1
1	2069	2
1	2069	3
1	2069	4
1	2069	5
1	2069	6
1	2069	7
1	2069	9
1	2069	13
1	2069	17
1	2069	21
1	2069	22
1	2069	23
1	2069	24
1	2069	25
1	2070	2
1	2070	4
1	2070	6
1	2070	8
1	2070	9
1	2070	12
1	2070	13
1	2070	14
1	2070	15
1	2070	16
1	2070	17
1	2070	19
1	2070	20
1	2070	24
1	2070	25
1	2071	1
1	2071	2
1	2071	4
1	2071	6
1	2071	9
1	2071	10
1	2071	11
1	2071	12
1	2071	13
1	2071	15
1	2071	16
1	2071	17
1	2071	20
1	2071	21
1	2071	25
1	2072	1
1	2072	3
1	2072	4
1	2072	9
1	2072	10
1	2072	11
1	2072	12
1	2072	13
1	2072	14
1	2072	15
1	2072	17
1	2072	18
1	2072	21
1	2072	22
1	2072	24
1	2073	4
1	2073	5
1	2073	6
1	2073	7
1	2073	11
1	2073	12
1	2073	13
1	2073	15
1	2073	16
1	2073	18
1	2073	19
1	2073	20
1	2073	23
1	2073	24
1	2073	25
1	2074	2
1	2074	3
1	2074	4
1	2074	5
1	2074	6
1	2074	9
1	2074	14
1	2074	15
1	2074	18
1	2074	19
1	2074	20
1	2074	21
1	2074	22
1	2074	24
1	2074	25
1	2075	2
1	2075	3
1	2075	5
1	2075	7
1	2075	8
1	2075	9
1	2075	11
1	2075	12
1	2075	13
1	2075	14
1	2075	17
1	2075	19
1	2075	23
1	2075	24
1	2075	25
1	2076	1
1	2076	3
1	2076	5
1	2076	6
1	2076	9
1	2076	10
1	2076	11
1	2076	12
1	2076	13
1	2076	14
1	2076	15
1	2076	18
1	2076	22
1	2076	24
1	2076	25
1	2077	3
1	2077	4
1	2077	5
1	2077	7
1	2077	8
1	2077	10
1	2077	11
1	2077	12
1	2077	13
1	2077	14
1	2077	15
1	2077	16
1	2077	21
1	2077	24
1	2077	25
1	2078	1
1	2078	2
1	2078	3
1	2078	4
1	2078	6
1	2078	12
1	2078	13
1	2078	15
1	2078	17
1	2078	18
1	2078	19
1	2078	21
1	2078	22
1	2078	24
1	2078	25
1	2079	1
1	2079	2
1	2079	3
1	2079	6
1	2079	9
1	2079	12
1	2079	14
1	2079	15
1	2079	17
1	2079	18
1	2079	19
1	2079	22
1	2079	23
1	2079	24
1	2079	25
1	2080	1
1	2080	2
1	2080	3
1	2080	5
1	2080	12
1	2080	13
1	2080	14
1	2080	15
1	2080	16
1	2080	17
1	2080	18
1	2080	21
1	2080	22
1	2080	23
1	2080	25
1	2081	2
1	2081	4
1	2081	5
1	2081	6
1	2081	7
1	2081	9
1	2081	10
1	2081	11
1	2081	15
1	2081	16
1	2081	17
1	2081	18
1	2081	19
1	2081	20
1	2081	21
1	2082	1
1	2082	4
1	2082	5
1	2082	6
1	2082	7
1	2082	8
1	2082	9
1	2082	10
1	2082	13
1	2082	15
1	2082	16
1	2082	17
1	2082	19
1	2082	20
1	2082	25
1	2083	4
1	2083	5
1	2083	7
1	2083	9
1	2083	10
1	2083	11
1	2083	12
1	2083	14
1	2083	16
1	2083	19
1	2083	20
1	2083	21
1	2083	22
1	2083	23
1	2083	24
1	2084	1
1	2084	3
1	2084	4
1	2084	5
1	2084	6
1	2084	8
1	2084	9
1	2084	10
1	2084	11
1	2084	14
1	2084	15
1	2084	16
1	2084	19
1	2084	22
1	2084	24
1	2085	1
1	2085	4
1	2085	6
1	2085	9
1	2085	10
1	2085	12
1	2085	13
1	2085	14
1	2085	15
1	2085	16
1	2085	18
1	2085	20
1	2085	23
1	2085	24
1	2085	25
1	2086	4
1	2086	5
1	2086	6
1	2086	10
1	2086	11
1	2086	12
1	2086	14
1	2086	15
1	2086	17
1	2086	20
1	2086	21
1	2086	22
1	2086	23
1	2086	24
1	2086	25
1	2087	3
1	2087	6
1	2087	8
1	2087	10
1	2087	13
1	2087	14
1	2087	15
1	2087	16
1	2087	17
1	2087	18
1	2087	19
1	2087	20
1	2087	23
1	2087	24
1	2087	25
1	2088	1
1	2088	2
1	2088	4
1	2088	5
1	2088	6
1	2088	7
1	2088	9
1	2088	11
1	2088	13
1	2088	14
1	2088	15
1	2088	21
1	2088	22
1	2088	23
1	2088	24
1	2089	1
1	2089	2
1	2089	5
1	2089	6
1	2089	8
1	2089	9
1	2089	10
1	2089	11
1	2089	12
1	2089	13
1	2089	16
1	2089	19
1	2089	20
1	2089	23
1	2089	25
1	2090	1
1	2090	6
1	2090	8
1	2090	9
1	2090	10
1	2090	12
1	2090	14
1	2090	15
1	2090	16
1	2090	18
1	2090	19
1	2090	20
1	2090	22
1	2090	24
1	2090	25
1	2091	2
1	2091	3
1	2091	4
1	2091	5
1	2091	6
1	2091	7
1	2091	8
1	2091	9
1	2091	10
1	2091	11
1	2091	16
1	2091	17
1	2091	19
1	2091	20
1	2091	24
1	2092	1
1	2092	2
1	2092	3
1	2092	5
1	2092	7
1	2092	9
1	2092	11
1	2092	13
1	2092	15
1	2092	17
1	2092	18
1	2092	19
1	2092	20
1	2092	22
1	2092	25
1	2093	1
1	2093	2
1	2093	3
1	2093	4
1	2093	6
1	2093	8
1	2093	9
1	2093	12
1	2093	14
1	2093	15
1	2093	19
1	2093	20
1	2093	21
1	2093	24
1	2093	25
1	2094	2
1	2094	4
1	2094	5
1	2094	6
1	2094	8
1	2094	9
1	2094	10
1	2094	11
1	2094	12
1	2094	14
1	2094	18
1	2094	19
1	2094	23
1	2094	24
1	2094	25
1	2095	1
1	2095	2
1	2095	4
1	2095	6
1	2095	8
1	2095	11
1	2095	12
1	2095	14
1	2095	15
1	2095	17
1	2095	18
1	2095	19
1	2095	20
1	2095	22
1	2095	23
1	2096	2
1	2096	3
1	2096	7
1	2096	8
1	2096	9
1	2096	10
1	2096	11
1	2096	13
1	2096	14
1	2096	15
1	2096	18
1	2096	19
1	2096	20
1	2096	21
1	2096	25
1	2097	2
1	2097	3
1	2097	6
1	2097	7
1	2097	8
1	2097	10
1	2097	12
1	2097	14
1	2097	15
1	2097	16
1	2097	18
1	2097	19
1	2097	21
1	2097	23
1	2097	24
1	2098	4
1	2098	7
1	2098	8
1	2098	9
1	2098	10
1	2098	12
1	2098	13
1	2098	15
1	2098	16
1	2098	17
1	2098	18
1	2098	19
1	2098	20
1	2098	22
1	2098	25
1	2099	1
1	2099	2
1	2099	5
1	2099	7
1	2099	8
1	2099	9
1	2099	11
1	2099	12
1	2099	14
1	2099	15
1	2099	17
1	2099	18
1	2099	20
1	2099	24
1	2099	25
1	2100	1
1	2100	3
1	2100	5
1	2100	6
1	2100	7
1	2100	10
1	2100	11
1	2100	14
1	2100	17
1	2100	18
1	2100	19
1	2100	20
1	2100	21
1	2100	23
1	2100	25
1	2101	1
1	2101	2
1	2101	3
1	2101	8
1	2101	10
1	2101	11
1	2101	14
1	2101	17
1	2101	18
1	2101	19
1	2101	20
1	2101	21
1	2101	23
1	2101	24
1	2101	25
1	2102	2
1	2102	3
1	2102	4
1	2102	5
1	2102	8
1	2102	9
1	2102	10
1	2102	11
1	2102	12
1	2102	13
1	2102	15
1	2102	16
1	2102	20
1	2102	22
1	2102	25
1	2103	1
1	2103	2
1	2103	5
1	2103	7
1	2103	10
1	2103	11
1	2103	12
1	2103	13
1	2103	15
1	2103	16
1	2103	18
1	2103	19
1	2103	20
1	2103	21
1	2103	25
1	2104	2
1	2104	4
1	2104	5
1	2104	6
1	2104	8
1	2104	9
1	2104	10
1	2104	11
1	2104	12
1	2104	14
1	2104	17
1	2104	18
1	2104	20
1	2104	21
1	2104	23
1	2105	3
1	2105	7
1	2105	8
1	2105	9
1	2105	10
1	2105	13
1	2105	14
1	2105	16
1	2105	17
1	2105	18
1	2105	19
1	2105	20
1	2105	21
1	2105	22
1	2105	25
1	2106	2
1	2106	4
1	2106	6
1	2106	7
1	2106	8
1	2106	9
1	2106	11
1	2106	12
1	2106	13
1	2106	14
1	2106	15
1	2106	16
1	2106	17
1	2106	21
1	2106	24
1	2107	1
1	2107	2
1	2107	3
1	2107	5
1	2107	7
1	2107	8
1	2107	9
1	2107	12
1	2107	13
1	2107	16
1	2107	18
1	2107	20
1	2107	22
1	2107	24
1	2107	25
1	2108	1
1	2108	3
1	2108	4
1	2108	5
1	2108	6
1	2108	7
1	2108	9
1	2108	13
1	2108	16
1	2108	17
1	2108	18
1	2108	19
1	2108	21
1	2108	24
1	2108	25
1	2109	2
1	2109	4
1	2109	5
1	2109	8
1	2109	9
1	2109	10
1	2109	11
1	2109	12
1	2109	13
1	2109	14
1	2109	16
1	2109	17
1	2109	21
1	2109	22
1	2109	23
1	2110	2
1	2110	6
1	2110	8
1	2110	10
1	2110	11
1	2110	13
1	2110	14
1	2110	15
1	2110	16
1	2110	17
1	2110	18
1	2110	21
1	2110	22
1	2110	24
1	2110	25
1	2111	1
1	2111	3
1	2111	4
1	2111	5
1	2111	9
1	2111	11
1	2111	12
1	2111	13
1	2111	14
1	2111	16
1	2111	19
1	2111	20
1	2111	21
1	2111	23
1	2111	24
1	2112	2
1	2112	3
1	2112	4
1	2112	7
1	2112	8
1	2112	9
1	2112	10
1	2112	11
1	2112	12
1	2112	15
1	2112	16
1	2112	18
1	2112	22
1	2112	24
1	2112	25
1	2113	1
1	2113	2
1	2113	4
1	2113	7
1	2113	8
1	2113	9
1	2113	10
1	2113	11
1	2113	13
1	2113	16
1	2113	17
1	2113	20
1	2113	22
1	2113	24
1	2113	25
1	2114	2
1	2114	5
1	2114	7
1	2114	8
1	2114	9
1	2114	10
1	2114	11
1	2114	15
1	2114	16
1	2114	17
1	2114	18
1	2114	19
1	2114	20
1	2114	21
1	2114	24
1	2115	3
1	2115	5
1	2115	7
1	2115	9
1	2115	10
1	2115	12
1	2115	13
1	2115	16
1	2115	17
1	2115	18
1	2115	20
1	2115	21
1	2115	22
1	2115	24
1	2115	25
1	2116	2
1	2116	3
1	2116	4
1	2116	6
1	2116	7
1	2116	8
1	2116	9
1	2116	10
1	2116	12
1	2116	13
1	2116	14
1	2116	18
1	2116	21
1	2116	24
1	2116	25
1	2117	1
1	2117	2
1	2117	4
1	2117	5
1	2117	7
1	2117	9
1	2117	14
1	2117	15
1	2117	16
1	2117	17
1	2117	19
1	2117	20
1	2117	21
1	2117	22
1	2117	24
1	2118	3
1	2118	6
1	2118	8
1	2118	9
1	2118	10
1	2118	11
1	2118	12
1	2118	14
1	2118	16
1	2118	17
1	2118	18
1	2118	19
1	2118	20
1	2118	22
1	2118	25
1	2119	1
1	2119	5
1	2119	6
1	2119	7
1	2119	8
1	2119	10
1	2119	12
1	2119	13
1	2119	14
1	2119	18
1	2119	20
1	2119	21
1	2119	22
1	2119	23
1	2119	24
1	2120	2
1	2120	4
1	2120	5
1	2120	8
1	2120	9
1	2120	12
1	2120	13
1	2120	14
1	2120	17
1	2120	18
1	2120	20
1	2120	21
1	2120	22
1	2120	23
1	2120	25
1	2121	1
1	2121	2
1	2121	4
1	2121	5
1	2121	7
1	2121	8
1	2121	9
1	2121	14
1	2121	17
1	2121	18
1	2121	19
1	2121	20
1	2121	22
1	2121	23
1	2121	25
1	2122	1
1	2122	3
1	2122	4
1	2122	5
1	2122	9
1	2122	10
1	2122	11
1	2122	14
1	2122	15
1	2122	18
1	2122	20
1	2122	21
1	2122	22
1	2122	23
1	2122	25
1	2123	1
1	2123	5
1	2123	6
1	2123	8
1	2123	9
1	2123	10
1	2123	14
1	2123	17
1	2123	18
1	2123	19
1	2123	20
1	2123	21
1	2123	23
1	2123	24
1	2123	25
1	2124	1
1	2124	3
1	2124	5
1	2124	6
1	2124	7
1	2124	8
1	2124	9
1	2124	10
1	2124	11
1	2124	13
1	2124	16
1	2124	22
1	2124	23
1	2124	24
1	2124	25
1	2125	1
1	2125	8
1	2125	10
1	2125	11
1	2125	12
1	2125	13
1	2125	15
1	2125	16
1	2125	17
1	2125	19
1	2125	20
1	2125	21
1	2125	23
1	2125	24
1	2125	25
1	2126	1
1	2126	3
1	2126	4
1	2126	5
1	2126	7
1	2126	8
1	2126	9
1	2126	10
1	2126	12
1	2126	15
1	2126	17
1	2126	21
1	2126	22
1	2126	24
1	2126	25
1	2127	2
1	2127	3
1	2127	4
1	2127	5
1	2127	6
1	2127	10
1	2127	11
1	2127	13
1	2127	14
1	2127	15
1	2127	16
1	2127	18
1	2127	20
1	2127	23
1	2127	24
1	2128	2
1	2128	3
1	2128	4
1	2128	6
1	2128	7
1	2128	9
1	2128	10
1	2128	11
1	2128	14
1	2128	16
1	2128	17
1	2128	18
1	2128	22
1	2128	23
1	2128	25
1	2129	1
1	2129	3
1	2129	4
1	2129	6
1	2129	7
1	2129	8
1	2129	10
1	2129	11
1	2129	14
1	2129	15
1	2129	19
1	2129	20
1	2129	21
1	2129	22
1	2129	24
1	2130	3
1	2130	4
1	2130	6
1	2130	7
1	2130	9
1	2130	10
1	2130	11
1	2130	12
1	2130	13
1	2130	14
1	2130	15
1	2130	16
1	2130	18
1	2130	20
1	2130	23
1	2131	1
1	2131	2
1	2131	3
1	2131	7
1	2131	8
1	2131	9
1	2131	10
1	2131	11
1	2131	13
1	2131	14
1	2131	16
1	2131	17
1	2131	19
1	2131	23
1	2131	25
1	2132	1
1	2132	3
1	2132	6
1	2132	9
1	2132	10
1	2132	11
1	2132	12
1	2132	15
1	2132	17
1	2132	19
1	2132	20
1	2132	21
1	2132	22
1	2132	23
1	2132	24
1	2133	2
1	2133	4
1	2133	6
1	2133	7
1	2133	8
1	2133	9
1	2133	10
1	2133	11
1	2133	14
1	2133	15
1	2133	17
1	2133	18
1	2133	19
1	2133	21
1	2133	23
1	2134	1
1	2134	3
1	2134	4
1	2134	6
1	2134	8
1	2134	10
1	2134	12
1	2134	14
1	2134	17
1	2134	18
1	2134	19
1	2134	20
1	2134	21
1	2134	22
1	2134	25
1	2135	1
1	2135	2
1	2135	3
1	2135	4
1	2135	5
1	2135	6
1	2135	8
1	2135	13
1	2135	15
1	2135	16
1	2135	18
1	2135	19
1	2135	21
1	2135	23
1	2135	25
1	2136	2
1	2136	3
1	2136	4
1	2136	6
1	2136	7
1	2136	9
1	2136	10
1	2136	13
1	2136	14
1	2136	16
1	2136	18
1	2136	19
1	2136	20
1	2136	24
1	2136	25
1	2137	2
1	2137	6
1	2137	7
1	2137	9
1	2137	11
1	2137	12
1	2137	13
1	2137	14
1	2137	16
1	2137	17
1	2137	18
1	2137	19
1	2137	20
1	2137	21
1	2137	23
1	2138	2
1	2138	3
1	2138	5
1	2138	6
1	2138	7
1	2138	8
1	2138	9
1	2138	12
1	2138	13
1	2138	16
1	2138	18
1	2138	19
1	2138	21
1	2138	22
1	2138	24
1	2139	1
1	2139	2
1	2139	3
1	2139	7
1	2139	8
1	2139	12
1	2139	13
1	2139	14
1	2139	16
1	2139	17
1	2139	18
1	2139	19
1	2139	22
1	2139	23
1	2139	25
1	2140	1
1	2140	3
1	2140	5
1	2140	6
1	2140	7
1	2140	8
1	2140	9
1	2140	11
1	2140	15
1	2140	17
1	2140	20
1	2140	21
1	2140	22
1	2140	23
1	2140	24
1	2141	1
1	2141	2
1	2141	3
1	2141	4
1	2141	5
1	2141	7
1	2141	8
1	2141	9
1	2141	10
1	2141	14
1	2141	18
1	2141	22
1	2141	23
1	2141	24
1	2141	25
1	2142	2
1	2142	4
1	2142	6
1	2142	7
1	2142	9
1	2142	11
1	2142	12
1	2142	14
1	2142	16
1	2142	17
1	2142	20
1	2142	22
1	2142	23
1	2142	24
1	2142	25
1	2143	1
1	2143	2
1	2143	3
1	2143	6
1	2143	9
1	2143	10
1	2143	11
1	2143	14
1	2143	17
1	2143	18
1	2143	19
1	2143	20
1	2143	21
1	2143	23
1	2143	25
1	2144	1
1	2144	2
1	2144	5
1	2144	6
1	2144	8
1	2144	9
1	2144	11
1	2144	12
1	2144	13
1	2144	14
1	2144	15
1	2144	17
1	2144	19
1	2144	20
1	2144	25
1	2145	2
1	2145	5
1	2145	6
1	2145	7
1	2145	8
1	2145	10
1	2145	12
1	2145	13
1	2145	14
1	2145	15
1	2145	17
1	2145	20
1	2145	23
1	2145	24
1	2145	25
1	2146	1
1	2146	2
1	2146	4
1	2146	6
1	2146	8
1	2146	9
1	2146	11
1	2146	13
1	2146	16
1	2146	17
1	2146	18
1	2146	19
1	2146	20
1	2146	21
1	2146	22
1	2147	1
1	2147	3
1	2147	5
1	2147	6
1	2147	7
1	2147	8
1	2147	9
1	2147	12
1	2147	14
1	2147	15
1	2147	16
1	2147	19
1	2147	20
1	2147	22
1	2147	25
1	2148	1
1	2148	3
1	2148	4
1	2148	7
1	2148	8
1	2148	11
1	2148	14
1	2148	15
1	2148	16
1	2148	18
1	2148	20
1	2148	22
1	2148	23
1	2148	24
1	2148	25
1	2149	1
1	2149	2
1	2149	4
1	2149	8
1	2149	9
1	2149	10
1	2149	12
1	2149	13
1	2149	14
1	2149	15
1	2149	16
1	2149	17
1	2149	18
1	2149	20
1	2149	23
1	2150	1
1	2150	2
1	2150	3
1	2150	5
1	2150	7
1	2150	8
1	2150	9
1	2150	11
1	2150	12
1	2150	14
1	2150	15
1	2150	16
1	2150	21
1	2150	23
1	2150	25
1	2151	1
1	2151	3
1	2151	6
1	2151	7
1	2151	8
1	2151	9
1	2151	11
1	2151	12
1	2151	13
1	2151	14
1	2151	15
1	2151	18
1	2151	21
1	2151	22
1	2151	24
1	2152	2
1	2152	3
1	2152	4
1	2152	6
1	2152	10
1	2152	11
1	2152	12
1	2152	13
1	2152	15
1	2152	16
1	2152	17
1	2152	18
1	2152	20
1	2152	23
1	2152	25
1	2153	1
1	2153	2
1	2153	4
1	2153	7
1	2153	8
1	2153	9
1	2153	10
1	2153	11
1	2153	13
1	2153	14
1	2153	15
1	2153	17
1	2153	18
1	2153	20
1	2153	21
1	2154	3
1	2154	4
1	2154	5
1	2154	7
1	2154	8
1	2154	10
1	2154	11
1	2154	12
1	2154	16
1	2154	18
1	2154	19
1	2154	20
1	2154	21
1	2154	23
1	2154	24
1	2155	1
1	2155	2
1	2155	3
1	2155	4
1	2155	6
1	2155	9
1	2155	13
1	2155	14
1	2155	15
1	2155	17
1	2155	18
1	2155	19
1	2155	20
1	2155	21
1	2155	22
1	2156	4
1	2156	5
1	2156	6
1	2156	7
1	2156	8
1	2156	10
1	2156	12
1	2156	13
1	2156	14
1	2156	17
1	2156	18
1	2156	19
1	2156	20
1	2156	21
1	2156	23
1	2157	2
1	2157	4
1	2157	5
1	2157	6
1	2157	12
1	2157	13
1	2157	14
1	2157	16
1	2157	17
1	2157	18
1	2157	19
1	2157	21
1	2157	22
1	2157	24
1	2157	25
1	2158	3
1	2158	5
1	2158	7
1	2158	8
1	2158	9
1	2158	12
1	2158	14
1	2158	17
1	2158	18
1	2158	19
1	2158	20
1	2158	21
1	2158	23
1	2158	24
1	2158	25
1	2159	1
1	2159	2
1	2159	4
1	2159	5
1	2159	7
1	2159	12
1	2159	13
1	2159	14
1	2159	16
1	2159	18
1	2159	20
1	2159	21
1	2159	22
1	2159	24
1	2159	25
1	2160	2
1	2160	4
1	2160	5
1	2160	6
1	2160	8
1	2160	11
1	2160	12
1	2160	14
1	2160	15
1	2160	16
1	2160	18
1	2160	19
1	2160	21
1	2160	24
1	2160	25
1	2161	1
1	2161	2
1	2161	3
1	2161	5
1	2161	6
1	2161	7
1	2161	9
1	2161	13
1	2161	14
1	2161	15
1	2161	18
1	2161	19
1	2161	22
1	2161	24
1	2161	25
1	2162	1
1	2162	2
1	2162	3
1	2162	5
1	2162	6
1	2162	8
1	2162	10
1	2162	12
1	2162	14
1	2162	15
1	2162	16
1	2162	17
1	2162	19
1	2162	21
1	2162	22
1	2163	1
1	2163	2
1	2163	4
1	2163	6
1	2163	10
1	2163	11
1	2163	12
1	2163	13
1	2163	16
1	2163	18
1	2163	19
1	2163	20
1	2163	21
1	2163	23
1	2163	25
1	2164	2
1	2164	3
1	2164	8
1	2164	10
1	2164	11
1	2164	13
1	2164	14
1	2164	15
1	2164	16
1	2164	17
1	2164	19
1	2164	20
1	2164	21
1	2164	24
1	2164	25
1	2165	1
1	2165	3
1	2165	5
1	2165	6
1	2165	8
1	2165	13
1	2165	14
1	2165	15
1	2165	16
1	2165	17
1	2165	18
1	2165	20
1	2165	21
1	2165	22
1	2165	23
1	2166	2
1	2166	3
1	2166	4
1	2166	6
1	2166	9
1	2166	10
1	2166	11
1	2166	12
1	2166	13
1	2166	14
1	2166	15
1	2166	18
1	2166	20
1	2166	21
1	2166	24
1	2167	2
1	2167	3
1	2167	4
1	2167	6
1	2167	7
1	2167	9
1	2167	11
1	2167	12
1	2167	14
1	2167	16
1	2167	17
1	2167	18
1	2167	19
1	2167	20
1	2167	23
1	2168	1
1	2168	3
1	2168	4
1	2168	6
1	2168	8
1	2168	10
1	2168	11
1	2168	12
1	2168	13
1	2168	14
1	2168	16
1	2168	17
1	2168	21
1	2168	23
1	2168	25
1	2169	1
1	2169	2
1	2169	4
1	2169	5
1	2169	8
1	2169	10
1	2169	11
1	2169	12
1	2169	13
1	2169	16
1	2169	20
1	2169	22
1	2169	23
1	2169	24
1	2169	25
1	2170	1
1	2170	6
1	2170	7
1	2170	9
1	2170	10
1	2170	11
1	2170	13
1	2170	17
1	2170	18
1	2170	19
1	2170	21
1	2170	22
1	2170	23
1	2170	24
1	2170	25
1	2171	1
1	2171	4
1	2171	9
1	2171	10
1	2171	11
1	2171	13
1	2171	15
1	2171	17
1	2171	18
1	2171	19
1	2171	21
1	2171	22
1	2171	23
1	2171	24
1	2171	25
1	2172	6
1	2172	8
1	2172	9
1	2172	10
1	2172	11
1	2172	13
1	2172	14
1	2172	15
1	2172	16
1	2172	17
1	2172	19
1	2172	20
1	2172	22
1	2172	23
1	2172	25
1	2173	1
1	2173	2
1	2173	3
1	2173	9
1	2173	11
1	2173	12
1	2173	13
1	2173	15
1	2173	16
1	2173	18
1	2173	19
1	2173	20
1	2173	21
1	2173	22
1	2173	25
1	2174	1
1	2174	2
1	2174	3
1	2174	5
1	2174	6
1	2174	7
1	2174	8
1	2174	11
1	2174	13
1	2174	14
1	2174	15
1	2174	16
1	2174	21
1	2174	24
1	2174	25
1	2175	1
1	2175	3
1	2175	5
1	2175	7
1	2175	10
1	2175	11
1	2175	12
1	2175	13
1	2175	14
1	2175	15
1	2175	16
1	2175	17
1	2175	19
1	2175	22
1	2175	23
1	2176	1
1	2176	2
1	2176	4
1	2176	5
1	2176	7
1	2176	8
1	2176	9
1	2176	11
1	2176	12
1	2176	13
1	2176	16
1	2176	18
1	2176	20
1	2176	21
1	2176	22
1	2177	1
1	2177	3
1	2177	4
1	2177	7
1	2177	8
1	2177	10
1	2177	12
1	2177	14
1	2177	15
1	2177	16
1	2177	17
1	2177	19
1	2177	20
1	2177	22
1	2177	24
1	2178	2
1	2178	5
1	2178	8
1	2178	9
1	2178	11
1	2178	13
1	2178	14
1	2178	15
1	2178	17
1	2178	18
1	2178	19
1	2178	20
1	2178	22
1	2178	23
1	2178	24
1	2179	3
1	2179	6
1	2179	7
1	2179	8
1	2179	9
1	2179	10
1	2179	13
1	2179	14
1	2179	15
1	2179	16
1	2179	18
1	2179	19
1	2179	20
1	2179	21
1	2179	25
1	2180	1
1	2180	3
1	2180	6
1	2180	7
1	2180	8
1	2180	9
1	2180	10
1	2180	11
1	2180	13
1	2180	14
1	2180	16
1	2180	18
1	2180	20
1	2180	21
1	2180	24
1	2181	1
1	2181	2
1	2181	3
1	2181	5
1	2181	6
1	2181	9
1	2181	11
1	2181	13
1	2181	14
1	2181	15
1	2181	17
1	2181	18
1	2181	22
1	2181	23
1	2181	25
1	2182	2
1	2182	3
1	2182	8
1	2182	9
1	2182	10
1	2182	12
1	2182	13
1	2182	14
1	2182	16
1	2182	17
1	2182	19
1	2182	20
1	2182	22
1	2182	23
1	2182	25
1	2183	1
1	2183	2
1	2183	4
1	2183	6
1	2183	9
1	2183	11
1	2183	14
1	2183	15
1	2183	16
1	2183	18
1	2183	19
1	2183	20
1	2183	21
1	2183	22
1	2183	25
1	2184	5
1	2184	7
1	2184	9
1	2184	10
1	2184	11
1	2184	12
1	2184	14
1	2184	15
1	2184	17
1	2184	19
1	2184	20
1	2184	21
1	2184	22
1	2184	24
1	2184	25
1	2185	1
1	2185	3
1	2185	5
1	2185	8
1	2185	9
1	2185	12
1	2185	13
1	2185	14
1	2185	16
1	2185	17
1	2185	18
1	2185	19
1	2185	20
1	2185	21
1	2185	25
1	2186	4
1	2186	6
1	2186	7
1	2186	9
1	2186	12
1	2186	13
1	2186	15
1	2186	16
1	2186	17
1	2186	18
1	2186	19
1	2186	22
1	2186	23
1	2186	24
1	2186	25
1	2187	3
1	2187	4
1	2187	6
1	2187	7
1	2187	8
1	2187	9
1	2187	10
1	2187	11
1	2187	13
1	2187	15
1	2187	16
1	2187	17
1	2187	21
1	2187	22
1	2187	24
1	2188	1
1	2188	3
1	2188	6
1	2188	8
1	2188	10
1	2188	11
1	2188	14
1	2188	15
1	2188	16
1	2188	17
1	2188	19
1	2188	20
1	2188	23
1	2188	24
1	2188	25
1	2189	1
1	2189	3
1	2189	4
1	2189	5
1	2189	6
1	2189	8
1	2189	10
1	2189	11
1	2189	13
1	2189	14
1	2189	17
1	2189	18
1	2189	19
1	2189	22
1	2189	24
1	2190	1
1	2190	2
1	2190	3
1	2190	4
1	2190	5
1	2190	8
1	2190	9
1	2190	11
1	2190	12
1	2190	13
1	2190	14
1	2190	16
1	2190	17
1	2190	23
1	2190	24
1	2191	3
1	2191	4
1	2191	5
1	2191	6
1	2191	10
1	2191	11
1	2191	13
1	2191	14
1	2191	15
1	2191	17
1	2191	18
1	2191	19
1	2191	20
1	2191	21
1	2191	23
1	2192	2
1	2192	3
1	2192	4
1	2192	5
1	2192	6
1	2192	7
1	2192	11
1	2192	12
1	2192	14
1	2192	17
1	2192	19
1	2192	21
1	2192	22
1	2192	23
1	2192	25
1	2193	2
1	2193	4
1	2193	5
1	2193	6
1	2193	7
1	2193	9
1	2193	10
1	2193	11
1	2193	13
1	2193	14
1	2193	19
1	2193	20
1	2193	22
1	2193	23
1	2193	24
1	2194	3
1	2194	4
1	2194	5
1	2194	6
1	2194	7
1	2194	8
1	2194	9
1	2194	11
1	2194	13
1	2194	15
1	2194	17
1	2194	19
1	2194	20
1	2194	22
1	2194	25
1	2195	2
1	2195	3
1	2195	5
1	2195	7
1	2195	8
1	2195	9
1	2195	11
1	2195	12
1	2195	13
1	2195	16
1	2195	17
1	2195	18
1	2195	20
1	2195	22
1	2195	23
1	2196	4
1	2196	5
1	2196	6
1	2196	8
1	2196	10
1	2196	11
1	2196	13
1	2196	15
1	2196	17
1	2196	18
1	2196	20
1	2196	21
1	2196	23
1	2196	24
1	2196	25
1	2197	1
1	2197	2
1	2197	3
1	2197	4
1	2197	7
1	2197	8
1	2197	10
1	2197	11
1	2197	13
1	2197	14
1	2197	15
1	2197	16
1	2197	17
1	2197	18
1	2197	21
1	2198	1
1	2198	4
1	2198	5
1	2198	7
1	2198	9
1	2198	11
1	2198	12
1	2198	13
1	2198	15
1	2198	17
1	2198	18
1	2198	20
1	2198	21
1	2198	22
1	2198	23
1	2199	1
1	2199	2
1	2199	5
1	2199	6
1	2199	7
1	2199	9
1	2199	12
1	2199	14
1	2199	15
1	2199	17
1	2199	18
1	2199	19
1	2199	20
1	2199	23
1	2199	24
1	2200	1
1	2200	2
1	2200	4
1	2200	6
1	2200	8
1	2200	9
1	2200	10
1	2200	11
1	2200	13
1	2200	14
1	2200	16
1	2200	17
1	2200	19
1	2200	23
1	2200	25
1	2201	1
1	2201	3
1	2201	5
1	2201	6
1	2201	7
1	2201	8
1	2201	9
1	2201	10
1	2201	13
1	2201	14
1	2201	16
1	2201	18
1	2201	19
1	2201	21
1	2201	24
1	2202	1
1	2202	5
1	2202	9
1	2202	10
1	2202	13
1	2202	14
1	2202	15
1	2202	16
1	2202	17
1	2202	18
1	2202	20
1	2202	21
1	2202	22
1	2202	24
1	2202	25
1	2203	2
1	2203	3
1	2203	5
1	2203	7
1	2203	10
1	2203	12
1	2203	13
1	2203	14
1	2203	18
1	2203	20
1	2203	21
1	2203	22
1	2203	23
1	2203	24
1	2203	25
1	2204	1
1	2204	2
1	2204	3
1	2204	4
1	2204	5
1	2204	6
1	2204	9
1	2204	11
1	2204	12
1	2204	13
1	2204	16
1	2204	18
1	2204	20
1	2204	23
1	2204	24
1	2205	1
1	2205	2
1	2205	5
1	2205	6
1	2205	7
1	2205	9
1	2205	10
1	2205	12
1	2205	14
1	2205	17
1	2205	18
1	2205	19
1	2205	22
1	2205	24
1	2205	25
1	2206	1
1	2206	2
1	2206	3
1	2206	4
1	2206	6
1	2206	8
1	2206	12
1	2206	13
1	2206	15
1	2206	16
1	2206	17
1	2206	20
1	2206	21
1	2206	23
1	2206	25
1	2207	3
1	2207	5
1	2207	6
1	2207	7
1	2207	8
1	2207	9
1	2207	10
1	2207	11
1	2207	12
1	2207	13
1	2207	14
1	2207	17
1	2207	20
1	2207	22
1	2207	25
1	2208	4
1	2208	5
1	2208	9
1	2208	10
1	2208	11
1	2208	12
1	2208	14
1	2208	15
1	2208	16
1	2208	18
1	2208	19
1	2208	21
1	2208	22
1	2208	23
1	2208	24
1	2209	1
1	2209	4
1	2209	5
1	2209	6
1	2209	7
1	2209	9
1	2209	11
1	2209	12
1	2209	14
1	2209	15
1	2209	16
1	2209	17
1	2209	21
1	2209	22
1	2209	23
1	2210	1
1	2210	3
1	2210	4
1	2210	8
1	2210	9
1	2210	10
1	2210	13
1	2210	14
1	2210	15
1	2210	16
1	2210	17
1	2210	19
1	2210	22
1	2210	23
1	2210	25
1	2211	4
1	2211	5
1	2211	8
1	2211	9
1	2211	10
1	2211	11
1	2211	12
1	2211	13
1	2211	17
1	2211	18
1	2211	19
1	2211	20
1	2211	21
1	2211	22
1	2211	23
1	2212	1
1	2212	4
1	2212	5
1	2212	6
1	2212	7
1	2212	8
1	2212	10
1	2212	11
1	2212	12
1	2212	13
1	2212	17
1	2212	18
1	2212	20
1	2212	21
1	2212	22
1	2213	3
1	2213	4
1	2213	5
1	2213	6
1	2213	7
1	2213	8
1	2213	10
1	2213	16
1	2213	17
1	2213	18
1	2213	19
1	2213	20
1	2213	22
1	2213	24
1	2213	25
1	2214	3
1	2214	6
1	2214	7
1	2214	9
1	2214	11
1	2214	12
1	2214	13
1	2214	14
1	2214	16
1	2214	17
1	2214	19
1	2214	21
1	2214	22
1	2214	23
1	2214	25
1	2215	2
1	2215	3
1	2215	4
1	2215	6
1	2215	7
1	2215	9
1	2215	11
1	2215	13
1	2215	15
1	2215	17
1	2215	18
1	2215	19
1	2215	23
1	2215	24
1	2215	25
1	2216	1
1	2216	2
1	2216	3
1	2216	4
1	2216	6
1	2216	9
1	2216	10
1	2216	13
1	2216	14
1	2216	15
1	2216	17
1	2216	19
1	2216	21
1	2216	22
1	2216	25
1	2217	1
1	2217	6
1	2217	7
1	2217	9
1	2217	10
1	2217	11
1	2217	14
1	2217	15
1	2217	16
1	2217	18
1	2217	19
1	2217	20
1	2217	22
1	2217	23
1	2217	25
1	2218	3
1	2218	4
1	2218	5
1	2218	6
1	2218	11
1	2218	12
1	2218	13
1	2218	15
1	2218	16
1	2218	17
1	2218	18
1	2218	20
1	2218	21
1	2218	23
1	2218	24
1	2219	2
1	2219	5
1	2219	6
1	2219	7
1	2219	8
1	2219	10
1	2219	13
1	2219	15
1	2219	16
1	2219	17
1	2219	19
1	2219	20
1	2219	22
1	2219	24
1	2219	25
1	2220	1
1	2220	5
1	2220	6
1	2220	7
1	2220	8
1	2220	9
1	2220	10
1	2220	12
1	2220	13
1	2220	16
1	2220	18
1	2220	20
1	2220	23
1	2220	24
1	2220	25
1	2221	1
1	2221	2
1	2221	3
1	2221	4
1	2221	5
1	2221	8
1	2221	9
1	2221	10
1	2221	12
1	2221	13
1	2221	16
1	2221	18
1	2221	20
1	2221	22
1	2221	23
1	2222	2
1	2222	4
1	2222	5
1	2222	6
1	2222	7
1	2222	8
1	2222	9
1	2222	10
1	2222	12
1	2222	13
1	2222	14
1	2222	19
1	2222	22
1	2222	23
1	2222	24
1	2223	1
1	2223	4
1	2223	5
1	2223	7
1	2223	8
1	2223	9
1	2223	11
1	2223	12
1	2223	14
1	2223	18
1	2223	20
1	2223	21
1	2223	22
1	2223	24
1	2223	25
1	2224	3
1	2224	5
1	2224	6
1	2224	7
1	2224	9
1	2224	10
1	2224	12
1	2224	13
1	2224	14
1	2224	15
1	2224	18
1	2224	19
1	2224	20
1	2224	23
1	2224	24
1	2225	2
1	2225	3
1	2225	4
1	2225	7
1	2225	8
1	2225	9
1	2225	10
1	2225	11
1	2225	13
1	2225	17
1	2225	19
1	2225	21
1	2225	22
1	2225	23
1	2225	25
1	2226	1
1	2226	3
1	2226	4
1	2226	5
1	2226	9
1	2226	10
1	2226	12
1	2226	13
1	2226	14
1	2226	15
1	2226	16
1	2226	17
1	2226	19
1	2226	21
1	2226	22
1	2227	2
1	2227	3
1	2227	7
1	2227	8
1	2227	9
1	2227	10
1	2227	11
1	2227	12
1	2227	15
1	2227	17
1	2227	20
1	2227	21
1	2227	22
1	2227	23
1	2227	24
1	2228	1
1	2228	4
1	2228	5
1	2228	6
1	2228	7
1	2228	11
1	2228	12
1	2228	13
1	2228	16
1	2228	17
1	2228	18
1	2228	19
1	2228	20
1	2228	22
1	2228	23
1	2229	1
1	2229	2
1	2229	3
1	2229	4
1	2229	7
1	2229	8
1	2229	9
1	2229	10
1	2229	14
1	2229	17
1	2229	19
1	2229	20
1	2229	23
1	2229	24
1	2229	25
1	2230	3
1	2230	4
1	2230	6
1	2230	8
1	2230	9
1	2230	10
1	2230	11
1	2230	13
1	2230	14
1	2230	15
1	2230	17
1	2230	18
1	2230	19
1	2230	20
1	2230	24
1	2231	1
1	2231	4
1	2231	5
1	2231	6
1	2231	7
1	2231	8
1	2231	10
1	2231	11
1	2231	16
1	2231	18
1	2231	19
1	2231	20
1	2231	22
1	2231	24
1	2231	25
1	2232	2
1	2232	4
1	2232	5
1	2232	6
1	2232	8
1	2232	9
1	2232	12
1	2232	13
1	2232	14
1	2232	19
1	2232	20
1	2232	22
1	2232	23
1	2232	24
1	2232	25
1	2233	1
1	2233	2
1	2233	6
1	2233	7
1	2233	8
1	2233	9
1	2233	10
1	2233	12
1	2233	13
1	2233	14
1	2233	15
1	2233	16
1	2233	20
1	2233	21
1	2233	25
1	2234	1
1	2234	2
1	2234	3
1	2234	6
1	2234	7
1	2234	11
1	2234	14
1	2234	15
1	2234	17
1	2234	18
1	2234	20
1	2234	21
1	2234	22
1	2234	24
1	2234	25
1	2235	2
1	2235	4
1	2235	6
1	2235	7
1	2235	8
1	2235	10
1	2235	11
1	2235	12
1	2235	16
1	2235	17
1	2235	19
1	2235	21
1	2235	22
1	2235	23
1	2235	25
1	2236	2
1	2236	3
1	2236	4
1	2236	5
1	2236	8
1	2236	9
1	2236	10
1	2236	11
1	2236	12
1	2236	17
1	2236	18
1	2236	19
1	2236	21
1	2236	22
1	2236	24
1	2237	3
1	2237	5
1	2237	6
1	2237	9
1	2237	12
1	2237	13
1	2237	14
1	2237	15
1	2237	17
1	2237	19
1	2237	20
1	2237	21
1	2237	22
1	2237	23
1	2237	25
1	2238	1
1	2238	3
1	2238	4
1	2238	5
1	2238	6
1	2238	7
1	2238	10
1	2238	11
1	2238	14
1	2238	15
1	2238	16
1	2238	18
1	2238	19
1	2238	20
1	2238	25
1	2239	1
1	2239	2
1	2239	5
1	2239	6
1	2239	7
1	2239	10
1	2239	13
1	2239	14
1	2239	15
1	2239	16
1	2239	17
1	2239	20
1	2239	22
1	2239	23
1	2239	24
1	2240	2
1	2240	3
1	2240	4
1	2240	6
1	2240	7
1	2240	9
1	2240	11
1	2240	12
1	2240	13
1	2240	15
1	2240	17
1	2240	18
1	2240	19
1	2240	20
1	2240	25
1	2241	1
1	2241	3
1	2241	7
1	2241	8
1	2241	9
1	2241	10
1	2241	13
1	2241	15
1	2241	16
1	2241	18
1	2241	20
1	2241	21
1	2241	23
1	2241	24
1	2241	25
1	2242	3
1	2242	4
1	2242	5
1	2242	8
1	2242	9
1	2242	10
1	2242	11
1	2242	12
1	2242	16
1	2242	17
1	2242	19
1	2242	20
1	2242	21
1	2242	22
1	2242	25
1	2243	1
1	2243	5
1	2243	6
1	2243	8
1	2243	10
1	2243	11
1	2243	14
1	2243	15
1	2243	17
1	2243	18
1	2243	19
1	2243	20
1	2243	21
1	2243	24
1	2243	25
1	2244	4
1	2244	5
1	2244	6
1	2244	8
1	2244	9
1	2244	10
1	2244	11
1	2244	13
1	2244	14
1	2244	15
1	2244	16
1	2244	17
1	2244	21
1	2244	23
1	2244	25
1	2245	2
1	2245	5
1	2245	6
1	2245	7
1	2245	8
1	2245	13
1	2245	14
1	2245	16
1	2245	17
1	2245	18
1	2245	21
1	2245	22
1	2245	23
1	2245	24
1	2245	25
1	2246	2
1	2246	3
1	2246	4
1	2246	5
1	2246	7
1	2246	8
1	2246	10
1	2246	11
1	2246	12
1	2246	13
1	2246	14
1	2246	15
1	2246	18
1	2246	20
1	2246	25
1	2247	1
1	2247	3
1	2247	6
1	2247	7
1	2247	8
1	2247	9
1	2247	10
1	2247	12
1	2247	17
1	2247	18
1	2247	19
1	2247	20
1	2247	22
1	2247	24
1	2247	25
1	2248	1
1	2248	2
1	2248	4
1	2248	6
1	2248	7
1	2248	8
1	2248	10
1	2248	11
1	2248	12
1	2248	13
1	2248	14
1	2248	16
1	2248	17
1	2248	23
1	2248	25
1	2249	2
1	2249	6
1	2249	11
1	2249	12
1	2249	14
1	2249	15
1	2249	16
1	2249	17
1	2249	18
1	2249	19
1	2249	21
1	2249	22
1	2249	23
1	2249	24
1	2249	25
1	2250	4
1	2250	5
1	2250	6
1	2250	10
1	2250	12
1	2250	13
1	2250	14
1	2250	18
1	2250	19
1	2250	20
1	2250	21
1	2250	22
1	2250	23
1	2250	24
1	2250	25
1	2251	2
1	2251	4
1	2251	5
1	2251	7
1	2251	9
1	2251	12
1	2251	13
1	2251	14
1	2251	15
1	2251	18
1	2251	19
1	2251	21
1	2251	22
1	2251	23
1	2251	24
1	2252	1
1	2252	5
1	2252	6
1	2252	8
1	2252	9
1	2252	10
1	2252	12
1	2252	16
1	2252	17
1	2252	19
1	2252	20
1	2252	21
1	2252	22
1	2252	24
1	2252	25
1	2253	2
1	2253	3
1	2253	5
1	2253	6
1	2253	7
1	2253	8
1	2253	12
1	2253	14
1	2253	15
1	2253	16
1	2253	18
1	2253	19
1	2253	20
1	2253	23
1	2253	25
1	2254	2
1	2254	3
1	2254	5
1	2254	6
1	2254	7
1	2254	8
1	2254	10
1	2254	12
1	2254	13
1	2254	14
1	2254	19
1	2254	20
1	2254	21
1	2254	24
1	2254	25
1	2255	1
1	2255	3
1	2255	6
1	2255	7
1	2255	8
1	2255	11
1	2255	14
1	2255	15
1	2255	17
1	2255	19
1	2255	20
1	2255	21
1	2255	22
1	2255	24
1	2255	25
1	2256	1
1	2256	3
1	2256	4
1	2256	5
1	2256	6
1	2256	8
1	2256	9
1	2256	10
1	2256	11
1	2256	12
1	2256	13
1	2256	16
1	2256	20
1	2256	23
1	2256	24
1	2257	1
1	2257	4
1	2257	5
1	2257	6
1	2257	7
1	2257	8
1	2257	9
1	2257	11
1	2257	12
1	2257	13
1	2257	15
1	2257	18
1	2257	20
1	2257	22
1	2257	24
1	2258	3
1	2258	5
1	2258	6
1	2258	7
1	2258	8
1	2258	10
1	2258	11
1	2258	14
1	2258	15
1	2258	16
1	2258	17
1	2258	19
1	2258	20
1	2258	22
1	2258	24
1	2259	5
1	2259	6
1	2259	7
1	2259	8
1	2259	9
1	2259	10
1	2259	14
1	2259	16
1	2259	18
1	2259	19
1	2259	20
1	2259	22
1	2259	23
1	2259	24
1	2259	25
1	2260	1
1	2260	2
1	2260	4
1	2260	6
1	2260	9
1	2260	10
1	2260	11
1	2260	12
1	2260	14
1	2260	16
1	2260	17
1	2260	20
1	2260	22
1	2260	23
1	2260	25
1	2261	1
1	2261	3
1	2261	4
1	2261	6
1	2261	7
1	2261	8
1	2261	9
1	2261	12
1	2261	13
1	2261	17
1	2261	18
1	2261	22
1	2261	23
1	2261	24
1	2261	25
1	2262	2
1	2262	3
1	2262	4
1	2262	6
1	2262	7
1	2262	8
1	2262	9
1	2262	10
1	2262	11
1	2262	19
1	2262	20
1	2262	21
1	2262	22
1	2262	24
1	2262	25
1	2263	1
1	2263	2
1	2263	3
1	2263	7
1	2263	8
1	2263	10
1	2263	11
1	2263	14
1	2263	15
1	2263	16
1	2263	18
1	2263	19
1	2263	22
1	2263	23
1	2263	25
1	2264	2
1	2264	3
1	2264	4
1	2264	5
1	2264	6
1	2264	8
1	2264	9
1	2264	10
1	2264	12
1	2264	14
1	2264	15
1	2264	16
1	2264	17
1	2264	18
1	2264	19
1	2265	2
1	2265	4
1	2265	5
1	2265	7
1	2265	9
1	2265	10
1	2265	12
1	2265	13
1	2265	14
1	2265	15
1	2265	16
1	2265	18
1	2265	19
1	2265	20
1	2265	22
1	2266	1
1	2266	3
1	2266	5
1	2266	9
1	2266	10
1	2266	11
1	2266	12
1	2266	13
1	2266	15
1	2266	16
1	2266	19
1	2266	21
1	2266	23
1	2266	24
1	2266	25
1	2267	2
1	2267	3
1	2267	5
1	2267	6
1	2267	7
1	2267	9
1	2267	10
1	2267	13
1	2267	14
1	2267	15
1	2267	17
1	2267	19
1	2267	20
1	2267	22
1	2267	24
1	2268	1
1	2268	3
1	2268	8
1	2268	10
1	2268	11
1	2268	12
1	2268	14
1	2268	15
1	2268	18
1	2268	19
1	2268	20
1	2268	21
1	2268	23
1	2268	24
1	2268	25
1	2269	2
1	2269	3
1	2269	4
1	2269	5
1	2269	7
1	2269	9
1	2269	10
1	2269	11
1	2269	13
1	2269	14
1	2269	17
1	2269	20
1	2269	21
1	2269	22
1	2269	25
1	2270	1
1	2270	4
1	2270	5
1	2270	6
1	2270	8
1	2270	10
1	2270	11
1	2270	15
1	2270	16
1	2270	18
1	2270	19
1	2270	20
1	2270	21
1	2270	22
1	2270	25
1	2271	2
1	2271	3
1	2271	5
1	2271	6
1	2271	7
1	2271	8
1	2271	10
1	2271	11
1	2271	16
1	2271	17
1	2271	18
1	2271	19
1	2271	21
1	2271	23
1	2271	24
1	2272	1
1	2272	2
1	2272	5
1	2272	7
1	2272	8
1	2272	10
1	2272	11
1	2272	13
1	2272	14
1	2272	15
1	2272	16
1	2272	18
1	2272	21
1	2272	22
1	2272	24
1	2273	1
1	2273	2
1	2273	4
1	2273	6
1	2273	7
1	2273	8
1	2273	9
1	2273	10
1	2273	11
1	2273	12
1	2273	13
1	2273	17
1	2273	21
1	2273	23
1	2273	25
1	2274	2
1	2274	3
1	2274	4
1	2274	6
1	2274	8
1	2274	9
1	2274	10
1	2274	12
1	2274	16
1	2274	17
1	2274	19
1	2274	20
1	2274	22
1	2274	23
1	2274	24
1	2275	1
1	2275	2
1	2275	4
1	2275	5
1	2275	7
1	2275	10
1	2275	11
1	2275	12
1	2275	13
1	2275	14
1	2275	15
1	2275	16
1	2275	19
1	2275	20
1	2275	21
1	2276	1
1	2276	4
1	2276	5
1	2276	7
1	2276	10
1	2276	12
1	2276	13
1	2276	14
1	2276	15
1	2276	16
1	2276	17
1	2276	18
1	2276	19
1	2276	20
1	2276	21
1	2277	2
1	2277	3
1	2277	5
1	2277	10
1	2277	11
1	2277	12
1	2277	13
1	2277	14
1	2277	15
1	2277	17
1	2277	18
1	2277	21
1	2277	22
1	2277	23
1	2277	24
1	2278	2
1	2278	4
1	2278	6
1	2278	7
1	2278	10
1	2278	11
1	2278	12
1	2278	13
1	2278	14
1	2278	16
1	2278	17
1	2278	18
1	2278	20
1	2278	21
1	2278	24
1	2279	1
1	2279	3
1	2279	5
1	2279	8
1	2279	10
1	2279	11
1	2279	13
1	2279	14
1	2279	15
1	2279	16
1	2279	17
1	2279	18
1	2279	21
1	2279	22
1	2279	25
1	2280	2
1	2280	3
1	2280	4
1	2280	7
1	2280	9
1	2280	12
1	2280	16
1	2280	18
1	2280	19
1	2280	20
1	2280	21
1	2280	22
1	2280	23
1	2280	24
1	2280	25
1	2281	2
1	2281	3
1	2281	5
1	2281	6
1	2281	7
1	2281	9
1	2281	10
1	2281	11
1	2281	14
1	2281	15
1	2281	16
1	2281	17
1	2281	18
1	2281	20
1	2281	21
1	2282	1
1	2282	2
1	2282	4
1	2282	5
1	2282	6
1	2282	10
1	2282	11
1	2282	12
1	2282	13
1	2282	14
1	2282	18
1	2282	20
1	2282	21
1	2282	23
1	2282	24
1	2283	1
1	2283	2
1	2283	5
1	2283	7
1	2283	9
1	2283	10
1	2283	11
1	2283	15
1	2283	17
1	2283	18
1	2283	19
1	2283	20
1	2283	22
1	2283	23
1	2283	25
1	2284	1
1	2284	3
1	2284	4
1	2284	8
1	2284	9
1	2284	10
1	2284	11
1	2284	14
1	2284	15
1	2284	17
1	2284	19
1	2284	20
1	2284	21
1	2284	23
1	2284	24
1	2285	1
1	2285	2
1	2285	6
1	2285	7
1	2285	8
1	2285	10
1	2285	12
1	2285	13
1	2285	15
1	2285	16
1	2285	18
1	2285	20
1	2285	22
1	2285	23
1	2285	24
1	2286	2
1	2286	3
1	2286	6
1	2286	8
1	2286	11
1	2286	12
1	2286	13
1	2286	15
1	2286	16
1	2286	17
1	2286	20
1	2286	22
1	2286	23
1	2286	24
1	2286	25
1	2287	1
1	2287	3
1	2287	4
1	2287	6
1	2287	7
1	2287	9
1	2287	10
1	2287	11
1	2287	12
1	2287	14
1	2287	16
1	2287	17
1	2287	18
1	2287	19
1	2287	25
1	2288	1
1	2288	2
1	2288	3
1	2288	5
1	2288	7
1	2288	9
1	2288	10
1	2288	11
1	2288	12
1	2288	14
1	2288	19
1	2288	20
1	2288	21
1	2288	22
1	2288	25
1	2289	1
1	2289	2
1	2289	5
1	2289	7
1	2289	8
1	2289	10
1	2289	12
1	2289	14
1	2289	15
1	2289	16
1	2289	17
1	2289	19
1	2289	20
1	2289	22
1	2289	25
1	2290	2
1	2290	3
1	2290	4
1	2290	5
1	2290	8
1	2290	9
1	2290	10
1	2290	11
1	2290	13
1	2290	15
1	2290	19
1	2290	22
1	2290	23
1	2290	24
1	2290	25
1	2291	1
1	2291	5
1	2291	6
1	2291	7
1	2291	9
1	2291	12
1	2291	13
1	2291	14
1	2291	16
1	2291	17
1	2291	19
1	2291	20
1	2291	21
1	2291	24
1	2291	25
1	2292	3
1	2292	5
1	2292	6
1	2292	7
1	2292	9
1	2292	10
1	2292	11
1	2292	12
1	2292	13
1	2292	18
1	2292	19
1	2292	20
1	2292	22
1	2292	23
1	2292	24
1	2293	1
1	2293	2
1	2293	4
1	2293	5
1	2293	8
1	2293	9
1	2293	11
1	2293	12
1	2293	13
1	2293	16
1	2293	18
1	2293	19
1	2293	20
1	2293	21
1	2293	22
1	2294	6
1	2294	7
1	2294	8
1	2294	10
1	2294	11
1	2294	12
1	2294	15
1	2294	16
1	2294	17
1	2294	18
1	2294	19
1	2294	22
1	2294	23
1	2294	24
1	2294	25
1	2295	1
1	2295	2
1	2295	6
1	2295	9
1	2295	10
1	2295	11
1	2295	12
1	2295	13
1	2295	14
1	2295	16
1	2295	17
1	2295	20
1	2295	23
1	2295	24
1	2295	25
1	2296	2
1	2296	3
1	2296	4
1	2296	8
1	2296	9
1	2296	10
1	2296	12
1	2296	14
1	2296	15
1	2296	16
1	2296	18
1	2296	21
1	2296	22
1	2296	23
1	2296	24
1	2297	2
1	2297	3
1	2297	7
1	2297	9
1	2297	11
1	2297	13
1	2297	14
1	2297	15
1	2297	17
1	2297	18
1	2297	20
1	2297	21
1	2297	22
1	2297	24
1	2297	25
1	2298	1
1	2298	3
1	2298	4
1	2298	6
1	2298	10
1	2298	12
1	2298	13
1	2298	14
1	2298	16
1	2298	18
1	2298	20
1	2298	21
1	2298	23
1	2298	24
1	2298	25
1	2299	1
1	2299	3
1	2299	5
1	2299	7
1	2299	8
1	2299	9
1	2299	11
1	2299	12
1	2299	14
1	2299	15
1	2299	16
1	2299	20
1	2299	21
1	2299	23
1	2299	25
1	2300	1
1	2300	2
1	2300	3
1	2300	4
1	2300	8
1	2300	9
1	2300	13
1	2300	15
1	2300	16
1	2300	17
1	2300	19
1	2300	22
1	2300	23
1	2300	24
1	2300	25
1	2301	3
1	2301	5
1	2301	9
1	2301	10
1	2301	12
1	2301	13
1	2301	15
1	2301	16
1	2301	17
1	2301	18
1	2301	19
1	2301	20
1	2301	22
1	2301	24
1	2301	25
1	2302	3
1	2302	4
1	2302	6
1	2302	7
1	2302	8
1	2302	10
1	2302	11
1	2302	12
1	2302	13
1	2302	14
1	2302	16
1	2302	17
1	2302	18
1	2302	20
1	2302	21
1	2303	1
1	2303	3
1	2303	5
1	2303	7
1	2303	8
1	2303	10
1	2303	11
1	2303	12
1	2303	15
1	2303	18
1	2303	19
1	2303	20
1	2303	21
1	2303	22
1	2303	24
1	2304	1
1	2304	2
1	2304	6
1	2304	8
1	2304	9
1	2304	11
1	2304	12
1	2304	13
1	2304	14
1	2304	16
1	2304	18
1	2304	20
1	2304	21
1	2304	22
1	2304	24
1	2305	1
1	2305	5
1	2305	7
1	2305	8
1	2305	10
1	2305	11
1	2305	14
1	2305	16
1	2305	17
1	2305	18
1	2305	19
1	2305	22
1	2305	23
1	2305	24
1	2305	25
1	2306	1
1	2306	4
1	2306	5
1	2306	6
1	2306	7
1	2306	8
1	2306	9
1	2306	11
1	2306	14
1	2306	15
1	2306	16
1	2306	18
1	2306	20
1	2306	21
1	2306	22
1	2307	1
1	2307	4
1	2307	5
1	2307	6
1	2307	8
1	2307	9
1	2307	11
1	2307	12
1	2307	13
1	2307	14
1	2307	15
1	2307	17
1	2307	19
1	2307	20
1	2307	23
1	2308	1
1	2308	2
1	2308	3
1	2308	4
1	2308	6
1	2308	10
1	2308	15
1	2308	17
1	2308	18
1	2308	19
1	2308	20
1	2308	22
1	2308	23
1	2308	24
1	2308	25
1	2309	1
1	2309	3
1	2309	4
1	2309	7
1	2309	9
1	2309	10
1	2309	11
1	2309	12
1	2309	13
1	2309	17
1	2309	18
1	2309	19
1	2309	22
1	2309	24
1	2309	25
1	2310	1
1	2310	3
1	2310	5
1	2310	6
1	2310	7
1	2310	10
1	2310	11
1	2310	13
1	2310	16
1	2310	18
1	2310	20
1	2310	22
1	2310	23
1	2310	24
1	2310	25
1	2311	1
1	2311	3
1	2311	4
1	2311	5
1	2311	9
1	2311	10
1	2311	12
1	2311	13
1	2311	14
1	2311	15
1	2311	18
1	2311	19
1	2311	20
1	2311	21
1	2311	25
1	2312	1
1	2312	2
1	2312	3
1	2312	6
1	2312	7
1	2312	10
1	2312	11
1	2312	12
1	2312	14
1	2312	15
1	2312	18
1	2312	20
1	2312	21
1	2312	22
1	2312	25
1	2313	4
1	2313	5
1	2313	6
1	2313	7
1	2313	8
1	2313	10
1	2313	11
1	2313	12
1	2313	14
1	2313	15
1	2313	18
1	2313	19
1	2313	20
1	2313	22
1	2313	25
1	2314	1
1	2314	2
1	2314	7
1	2314	8
1	2314	9
1	2314	11
1	2314	13
1	2314	14
1	2314	15
1	2314	17
1	2314	19
1	2314	20
1	2314	23
1	2314	24
1	2314	25
1	2315	3
1	2315	7
1	2315	8
1	2315	11
1	2315	12
1	2315	13
1	2315	14
1	2315	16
1	2315	17
1	2315	18
1	2315	19
1	2315	21
1	2315	22
1	2315	23
1	2315	25
1	2316	2
1	2316	3
1	2316	4
1	2316	5
1	2316	6
1	2316	9
1	2316	10
1	2316	13
1	2316	14
1	2316	15
1	2316	16
1	2316	17
1	2316	19
1	2316	24
1	2316	25
1	2317	1
1	2317	2
1	2317	3
1	2317	5
1	2317	6
1	2317	7
1	2317	9
1	2317	14
1	2317	15
1	2317	16
1	2317	17
1	2317	20
1	2317	21
1	2317	23
1	2317	25
1	2318	2
1	2318	5
1	2318	6
1	2318	7
1	2318	8
1	2318	11
1	2318	13
1	2318	16
1	2318	17
1	2318	18
1	2318	19
1	2318	20
1	2318	21
1	2318	24
1	2318	25
1	2319	2
1	2319	3
1	2319	8
1	2319	12
1	2319	13
1	2319	14
1	2319	15
1	2319	16
1	2319	17
1	2319	19
1	2319	21
1	2319	22
1	2319	23
1	2319	24
1	2319	25
1	2320	1
1	2320	2
1	2320	3
1	2320	5
1	2320	6
1	2320	9
1	2320	12
1	2320	13
1	2320	15
1	2320	17
1	2320	21
1	2320	22
1	2320	23
1	2320	24
1	2320	25
1	2321	1
1	2321	2
1	2321	6
1	2321	7
1	2321	8
1	2321	9
1	2321	10
1	2321	12
1	2321	13
1	2321	14
1	2321	15
1	2321	17
1	2321	22
1	2321	23
1	2321	24
1	2322	1
1	2322	2
1	2322	5
1	2322	6
1	2322	7
1	2322	11
1	2322	12
1	2322	13
1	2322	14
1	2322	16
1	2322	18
1	2322	21
1	2322	22
1	2322	23
1	2322	24
1	2323	1
1	2323	4
1	2323	7
1	2323	8
1	2323	11
1	2323	13
1	2323	14
1	2323	16
1	2323	17
1	2323	19
1	2323	21
1	2323	22
1	2323	23
1	2323	24
1	2323	25
1	2324	1
1	2324	2
1	2324	3
1	2324	5
1	2324	8
1	2324	9
1	2324	10
1	2324	11
1	2324	13
1	2324	14
1	2324	16
1	2324	17
1	2324	19
1	2324	20
1	2324	25
1	2325	1
1	2325	2
1	2325	3
1	2325	4
1	2325	5
1	2325	6
1	2325	7
1	2325	8
1	2325	9
1	2325	14
1	2325	17
1	2325	18
1	2325	21
1	2325	23
1	2325	25
1	2326	2
1	2326	3
1	2326	4
1	2326	5
1	2326	6
1	2326	8
1	2326	11
1	2326	12
1	2326	13
1	2326	14
1	2326	16
1	2326	20
1	2326	22
1	2326	23
1	2326	25
1	2327	1
1	2327	2
1	2327	3
1	2327	4
1	2327	6
1	2327	7
1	2327	8
1	2327	11
1	2327	13
1	2327	15
1	2327	17
1	2327	19
1	2327	20
1	2327	21
1	2327	25
1	2328	3
1	2328	4
1	2328	5
1	2328	6
1	2328	7
1	2328	8
1	2328	9
1	2328	11
1	2328	14
1	2328	15
1	2328	17
1	2328	20
1	2328	21
1	2328	23
1	2328	25
1	2329	1
1	2329	3
1	2329	4
1	2329	5
1	2329	10
1	2329	11
1	2329	12
1	2329	13
1	2329	14
1	2329	16
1	2329	17
1	2329	18
1	2329	19
1	2329	20
1	2329	24
1	2330	2
1	2330	4
1	2330	5
1	2330	8
1	2330	10
1	2330	11
1	2330	12
1	2330	13
1	2330	14
1	2330	15
1	2330	16
1	2330	18
1	2330	20
1	2330	22
1	2330	23
1	2331	3
1	2331	4
1	2331	5
1	2331	7
1	2331	8
1	2331	9
1	2331	10
1	2331	13
1	2331	14
1	2331	15
1	2331	16
1	2331	20
1	2331	22
1	2331	24
1	2331	25
1	2332	1
1	2332	4
1	2332	6
1	2332	7
1	2332	8
1	2332	9
1	2332	10
1	2332	11
1	2332	14
1	2332	17
1	2332	18
1	2332	20
1	2332	22
1	2332	24
1	2332	25
1	2333	1
1	2333	4
1	2333	6
1	2333	7
1	2333	8
1	2333	9
1	2333	10
1	2333	11
1	2333	13
1	2333	15
1	2333	17
1	2333	18
1	2333	19
1	2333	20
1	2333	23
1	2334	2
1	2334	3
1	2334	5
1	2334	7
1	2334	13
1	2334	14
1	2334	16
1	2334	17
1	2334	18
1	2334	20
1	2334	21
1	2334	22
1	2334	23
1	2334	24
1	2334	25
1	2335	2
1	2335	3
1	2335	4
1	2335	5
1	2335	6
1	2335	7
1	2335	9
1	2335	13
1	2335	15
1	2335	16
1	2335	19
1	2335	21
1	2335	22
1	2335	24
1	2335	25
1	2336	1
1	2336	3
1	2336	4
1	2336	6
1	2336	10
1	2336	11
1	2336	12
1	2336	13
1	2336	14
1	2336	16
1	2336	17
1	2336	18
1	2336	20
1	2336	22
1	2336	25
1	2337	1
1	2337	2
1	2337	4
1	2337	5
1	2337	6
1	2337	8
1	2337	9
1	2337	10
1	2337	11
1	2337	14
1	2337	16
1	2337	19
1	2337	20
1	2337	21
1	2337	24
1	2338	1
1	2338	2
1	2338	3
1	2338	4
1	2338	5
1	2338	7
1	2338	8
1	2338	10
1	2338	11
1	2338	12
1	2338	13
1	2338	15
1	2338	16
1	2338	19
1	2338	21
1	2339	1
1	2339	3
1	2339	6
1	2339	7
1	2339	8
1	2339	10
1	2339	11
1	2339	14
1	2339	18
1	2339	19
1	2339	20
1	2339	22
1	2339	23
1	2339	24
1	2339	25
1	2340	2
1	2340	5
1	2340	7
1	2340	8
1	2340	9
1	2340	11
1	2340	12
1	2340	13
1	2340	14
1	2340	17
1	2340	18
1	2340	20
1	2340	22
1	2340	23
1	2340	25
1	2341	2
1	2341	4
1	2341	5
1	2341	7
1	2341	9
1	2341	11
1	2341	12
1	2341	14
1	2341	15
1	2341	19
1	2341	20
1	2341	21
1	2341	22
1	2341	24
1	2341	25
1	2342	1
1	2342	2
1	2342	3
1	2342	4
1	2342	9
1	2342	10
1	2342	13
1	2342	15
1	2342	16
1	2342	18
1	2342	19
1	2342	20
1	2342	21
1	2342	22
1	2342	25
1	2343	1
1	2343	2
1	2343	5
1	2343	9
1	2343	12
1	2343	15
1	2343	16
1	2343	17
1	2343	18
1	2343	19
1	2343	20
1	2343	22
1	2343	23
1	2343	24
1	2343	25
1	2344	1
1	2344	3
1	2344	4
1	2344	6
1	2344	7
1	2344	9
1	2344	10
1	2344	11
1	2344	12
1	2344	13
1	2344	16
1	2344	17
1	2344	19
1	2344	20
1	2344	21
1	2345	3
1	2345	6
1	2345	7
1	2345	9
1	2345	10
1	2345	11
1	2345	12
1	2345	14
1	2345	16
1	2345	17
1	2345	19
1	2345	20
1	2345	23
1	2345	24
1	2345	25
1	2346	1
1	2346	4
1	2346	5
1	2346	8
1	2346	10
1	2346	11
1	2346	12
1	2346	14
1	2346	16
1	2346	17
1	2346	18
1	2346	19
1	2346	21
1	2346	22
1	2346	25
1	2347	2
1	2347	3
1	2347	5
1	2347	6
1	2347	8
1	2347	9
1	2347	11
1	2347	13
1	2347	15
1	2347	16
1	2347	17
1	2347	19
1	2347	21
1	2347	24
1	2347	25
1	2348	1
1	2348	2
1	2348	5
1	2348	8
1	2348	9
1	2348	11
1	2348	13
1	2348	14
1	2348	15
1	2348	17
1	2348	19
1	2348	20
1	2348	22
1	2348	23
1	2348	24
1	2349	2
1	2349	5
1	2349	6
1	2349	9
1	2349	10
1	2349	11
1	2349	12
1	2349	15
1	2349	16
1	2349	17
1	2349	18
1	2349	20
1	2349	21
1	2349	22
1	2349	23
1	2350	2
1	2350	3
1	2350	4
1	2350	5
1	2350	6
1	2350	7
1	2350	8
1	2350	9
1	2350	10
1	2350	15
1	2350	17
1	2350	19
1	2350	21
1	2350	22
1	2350	25
1	2351	1
1	2351	3
1	2351	4
1	2351	5
1	2351	6
1	2351	7
1	2351	8
1	2351	9
1	2351	10
1	2351	12
1	2351	14
1	2351	15
1	2351	20
1	2351	23
1	2351	24
1	2352	3
1	2352	4
1	2352	7
1	2352	8
1	2352	11
1	2352	12
1	2352	15
1	2352	16
1	2352	17
1	2352	18
1	2352	20
1	2352	22
1	2352	23
1	2352	24
1	2352	25
1	2353	1
1	2353	2
1	2353	3
1	2353	7
1	2353	8
1	2353	12
1	2353	13
1	2353	14
1	2353	15
1	2353	16
1	2353	18
1	2353	20
1	2353	23
1	2353	24
1	2353	25
1	2354	1
1	2354	2
1	2354	5
1	2354	6
1	2354	9
1	2354	10
1	2354	11
1	2354	12
1	2354	13
1	2354	16
1	2354	17
1	2354	18
1	2354	19
1	2354	20
1	2354	21
1	2355	2
1	2355	3
1	2355	4
1	2355	5
1	2355	6
1	2355	8
1	2355	9
1	2355	10
1	2355	11
1	2355	12
1	2355	18
1	2355	19
1	2355	20
1	2355	21
1	2355	25
1	2356	3
1	2356	5
1	2356	6
1	2356	7
1	2356	8
1	2356	9
1	2356	10
1	2356	13
1	2356	16
1	2356	18
1	2356	19
1	2356	20
1	2356	21
1	2356	22
1	2356	25
1	2357	1
1	2357	2
1	2357	4
1	2357	6
1	2357	7
1	2357	8
1	2357	9
1	2357	10
1	2357	12
1	2357	13
1	2357	14
1	2357	20
1	2357	23
1	2357	24
1	2357	25
1	2358	4
1	2358	5
1	2358	6
1	2358	7
1	2358	8
1	2358	11
1	2358	12
1	2358	14
1	2358	15
1	2358	16
1	2358	17
1	2358	20
1	2358	23
1	2358	24
1	2358	25
1	2359	3
1	2359	4
1	2359	5
1	2359	6
1	2359	7
1	2359	12
1	2359	14
1	2359	15
1	2359	17
1	2359	19
1	2359	20
1	2359	21
1	2359	22
1	2359	23
1	2359	24
1	2360	3
1	2360	5
1	2360	6
1	2360	8
1	2360	11
1	2360	12
1	2360	13
1	2360	15
1	2360	17
1	2360	18
1	2360	19
1	2360	21
1	2360	22
1	2360	23
1	2360	25
1	2361	3
1	2361	4
1	2361	5
1	2361	7
1	2361	10
1	2361	12
1	2361	13
1	2361	14
1	2361	16
1	2361	18
1	2361	19
1	2361	21
1	2361	22
1	2361	23
1	2361	24
1	2362	1
1	2362	4
1	2362	6
1	2362	7
1	2362	8
1	2362	10
1	2362	11
1	2362	12
1	2362	14
1	2362	18
1	2362	19
1	2362	21
1	2362	22
1	2362	24
1	2362	25
1	2363	1
1	2363	2
1	2363	3
1	2363	4
1	2363	8
1	2363	11
1	2363	12
1	2363	13
1	2363	14
1	2363	15
1	2363	20
1	2363	21
1	2363	22
1	2363	24
1	2363	25
1	2364	1
1	2364	5
1	2364	6
1	2364	7
1	2364	8
1	2364	9
1	2364	10
1	2364	11
1	2364	13
1	2364	15
1	2364	16
1	2364	17
1	2364	18
1	2364	22
1	2364	24
1	2365	2
1	2365	7
1	2365	8
1	2365	9
1	2365	11
1	2365	14
1	2365	15
1	2365	16
1	2365	17
1	2365	18
1	2365	20
1	2365	21
1	2365	22
1	2365	23
1	2365	25
1	2366	1
1	2366	3
1	2366	5
1	2366	7
1	2366	10
1	2366	11
1	2366	13
1	2366	15
1	2366	16
1	2366	18
1	2366	19
1	2366	20
1	2366	21
1	2366	22
1	2366	25
1	2367	2
1	2367	3
1	2367	5
1	2367	8
1	2367	9
1	2367	10
1	2367	11
1	2367	12
1	2367	14
1	2367	16
1	2367	17
1	2367	19
1	2367	22
1	2367	23
1	2367	25
1	2368	2
1	2368	3
1	2368	4
1	2368	7
1	2368	8
1	2368	9
1	2368	10
1	2368	11
1	2368	12
1	2368	14
1	2368	16
1	2368	18
1	2368	19
1	2368	22
1	2368	23
1	2369	2
1	2369	3
1	2369	5
1	2369	8
1	2369	9
1	2369	10
1	2369	11
1	2369	12
1	2369	13
1	2369	14
1	2369	15
1	2369	22
1	2369	23
1	2369	24
1	2369	25
1	2370	1
1	2370	7
1	2370	8
1	2370	9
1	2370	10
1	2370	11
1	2370	12
1	2370	13
1	2370	14
1	2370	16
1	2370	19
1	2370	20
1	2370	21
1	2370	24
1	2370	25
1	2371	3
1	2371	5
1	2371	6
1	2371	8
1	2371	11
1	2371	12
1	2371	13
1	2371	14
1	2371	15
1	2371	19
1	2371	21
1	2371	22
1	2371	23
1	2371	24
1	2371	25
1	2372	1
1	2372	2
1	2372	4
1	2372	5
1	2372	7
1	2372	8
1	2372	11
1	2372	13
1	2372	14
1	2372	15
1	2372	19
1	2372	20
1	2372	21
1	2372	22
1	2372	24
1	2373	2
1	2373	3
1	2373	4
1	2373	5
1	2373	6
1	2373	7
1	2373	8
1	2373	10
1	2373	13
1	2373	14
1	2373	15
1	2373	17
1	2373	21
1	2373	24
1	2373	25
1	2374	1
1	2374	3
1	2374	5
1	2374	7
1	2374	9
1	2374	10
1	2374	14
1	2374	15
1	2374	16
1	2374	17
1	2374	20
1	2374	21
1	2374	22
1	2374	23
1	2374	25
1	2375	4
1	2375	5
1	2375	8
1	2375	11
1	2375	12
1	2375	13
1	2375	14
1	2375	17
1	2375	18
1	2375	19
1	2375	20
1	2375	21
1	2375	22
1	2375	23
1	2375	25
1	2376	1
1	2376	2
1	2376	4
1	2376	6
1	2376	8
1	2376	9
1	2376	14
1	2376	15
1	2376	16
1	2376	17
1	2376	19
1	2376	21
1	2376	22
1	2376	23
1	2376	24
1	2377	1
1	2377	2
1	2377	3
1	2377	4
1	2377	5
1	2377	6
1	2377	8
1	2377	9
1	2377	10
1	2377	12
1	2377	14
1	2377	18
1	2377	19
1	2377	20
1	2377	24
1	2378	1
1	2378	2
1	2378	3
1	2378	4
1	2378	5
1	2378	10
1	2378	12
1	2378	14
1	2378	15
1	2378	16
1	2378	17
1	2378	21
1	2378	23
1	2378	24
1	2378	25
1	2379	1
1	2379	2
1	2379	3
1	2379	5
1	2379	7
1	2379	8
1	2379	9
1	2379	11
1	2379	12
1	2379	15
1	2379	16
1	2379	20
1	2379	23
1	2379	24
1	2379	25
1	2380	1
1	2380	3
1	2380	5
1	2380	6
1	2380	7
1	2380	9
1	2380	10
1	2380	11
1	2380	13
1	2380	14
1	2380	15
1	2380	17
1	2380	21
1	2380	22
1	2380	24
1	2381	1
1	2381	2
1	2381	5
1	2381	8
1	2381	9
1	2381	10
1	2381	11
1	2381	14
1	2381	15
1	2381	18
1	2381	19
1	2381	20
1	2381	23
1	2381	24
1	2381	25
1	2382	1
1	2382	2
1	2382	3
1	2382	4
1	2382	5
1	2382	6
1	2382	7
1	2382	9
1	2382	10
1	2382	11
1	2382	14
1	2382	15
1	2382	19
1	2382	21
1	2382	24
1	2383	1
1	2383	2
1	2383	3
1	2383	7
1	2383	9
1	2383	11
1	2383	12
1	2383	13
1	2383	14
1	2383	15
1	2383	16
1	2383	18
1	2383	20
1	2383	22
1	2383	24
1	2384	1
1	2384	3
1	2384	4
1	2384	5
1	2384	7
1	2384	9
1	2384	10
1	2384	11
1	2384	13
1	2384	15
1	2384	16
1	2384	18
1	2384	20
1	2384	22
1	2384	24
1	2385	1
1	2385	2
1	2385	3
1	2385	5
1	2385	10
1	2385	11
1	2385	12
1	2385	13
1	2385	16
1	2385	17
1	2385	18
1	2385	21
1	2385	22
1	2385	23
1	2385	24
1	2386	2
1	2386	3
1	2386	6
1	2386	7
1	2386	8
1	2386	10
1	2386	12
1	2386	13
1	2386	14
1	2386	15
1	2386	16
1	2386	17
1	2386	18
1	2386	23
1	2386	24
1	2387	2
1	2387	4
1	2387	5
1	2387	8
1	2387	9
1	2387	10
1	2387	12
1	2387	16
1	2387	17
1	2387	19
1	2387	20
1	2387	21
1	2387	22
1	2387	24
1	2387	25
1	2388	3
1	2388	4
1	2388	5
1	2388	7
1	2388	8
1	2388	9
1	2388	10
1	2388	12
1	2388	13
1	2388	15
1	2388	16
1	2388	17
1	2388	19
1	2388	23
1	2388	25
1	2389	4
1	2389	5
1	2389	6
1	2389	8
1	2389	9
1	2389	10
1	2389	11
1	2389	12
1	2389	18
1	2389	19
1	2389	21
1	2389	22
1	2389	23
1	2389	24
1	2389	25
1	2390	1
1	2390	2
1	2390	3
1	2390	4
1	2390	5
1	2390	6
1	2390	10
1	2390	11
1	2390	15
1	2390	19
1	2390	20
1	2390	21
1	2390	22
1	2390	23
1	2390	24
1	2391	3
1	2391	4
1	2391	5
1	2391	6
1	2391	8
1	2391	9
1	2391	11
1	2391	12
1	2391	14
1	2391	18
1	2391	19
1	2391	21
1	2391	22
1	2391	24
1	2391	25
1	2392	1
1	2392	2
1	2392	5
1	2392	6
1	2392	8
1	2392	11
1	2392	12
1	2392	13
1	2392	16
1	2392	17
1	2392	18
1	2392	22
1	2392	23
1	2392	24
1	2392	25
1	2393	2
1	2393	3
1	2393	5
1	2393	10
1	2393	11
1	2393	12
1	2393	15
1	2393	16
1	2393	17
1	2393	19
1	2393	20
1	2393	21
1	2393	22
1	2393	23
1	2393	25
1	2394	1
1	2394	4
1	2394	6
1	2394	7
1	2394	9
1	2394	10
1	2394	12
1	2394	17
1	2394	18
1	2394	19
1	2394	20
1	2394	21
1	2394	22
1	2394	23
1	2394	25
1	2395	1
1	2395	2
1	2395	5
1	2395	6
1	2395	7
1	2395	10
1	2395	13
1	2395	14
1	2395	15
1	2395	17
1	2395	18
1	2395	19
1	2395	20
1	2395	23
1	2395	25
1	2396	1
1	2396	3
1	2396	4
1	2396	7
1	2396	10
1	2396	12
1	2396	13
1	2396	16
1	2396	17
1	2396	18
1	2396	20
1	2396	22
1	2396	23
1	2396	24
1	2396	25
1	2397	2
1	2397	4
1	2397	6
1	2397	7
1	2397	9
1	2397	10
1	2397	13
1	2397	14
1	2397	15
1	2397	17
1	2397	18
1	2397	20
1	2397	21
1	2397	22
1	2397	25
1	2398	2
1	2398	3
1	2398	4
1	2398	5
1	2398	6
1	2398	9
1	2398	10
1	2398	12
1	2398	13
1	2398	14
1	2398	15
1	2398	20
1	2398	22
1	2398	23
1	2398	25
1	2399	1
1	2399	2
1	2399	4
1	2399	5
1	2399	7
1	2399	9
1	2399	12
1	2399	14
1	2399	15
1	2399	16
1	2399	17
1	2399	19
1	2399	20
1	2399	21
1	2399	25
1	2400	2
1	2400	3
1	2400	5
1	2400	9
1	2400	10
1	2400	11
1	2400	12
1	2400	13
1	2400	14
1	2400	15
1	2400	16
1	2400	20
1	2400	21
1	2400	23
1	2400	25
1	2401	1
1	2401	4
1	2401	5
1	2401	6
1	2401	7
1	2401	9
1	2401	10
1	2401	11
1	2401	12
1	2401	15
1	2401	16
1	2401	19
1	2401	20
1	2401	22
1	2401	23
1	2402	1
1	2402	2
1	2402	3
1	2402	4
1	2402	5
1	2402	6
1	2402	9
1	2402	10
1	2402	11
1	2402	13
1	2402	14
1	2402	18
1	2402	20
1	2402	23
1	2402	25
1	2403	1
1	2403	4
1	2403	5
1	2403	8
1	2403	10
1	2403	12
1	2403	16
1	2403	17
1	2403	18
1	2403	19
1	2403	20
1	2403	21
1	2403	23
1	2403	24
1	2403	25
1	2404	1
1	2404	2
1	2404	3
1	2404	4
1	2404	5
1	2404	7
1	2404	10
1	2404	11
1	2404	12
1	2404	14
1	2404	15
1	2404	22
1	2404	23
1	2404	24
1	2404	25
1	2405	2
1	2405	3
1	2405	4
1	2405	5
1	2405	6
1	2405	7
1	2405	8
1	2405	9
1	2405	11
1	2405	15
1	2405	17
1	2405	18
1	2405	19
1	2405	21
1	2405	23
1	2406	1
1	2406	2
1	2406	3
1	2406	5
1	2406	6
1	2406	8
1	2406	10
1	2406	12
1	2406	15
1	2406	17
1	2406	20
1	2406	21
1	2406	23
1	2406	24
1	2406	25
1	2407	1
1	2407	2
1	2407	3
1	2407	4
1	2407	6
1	2407	8
1	2407	9
1	2407	11
1	2407	12
1	2407	17
1	2407	18
1	2407	19
1	2407	20
1	2407	23
1	2407	24
1	2408	1
1	2408	3
1	2408	4
1	2408	6
1	2408	8
1	2408	9
1	2408	10
1	2408	11
1	2408	12
1	2408	13
1	2408	16
1	2408	19
1	2408	21
1	2408	22
1	2408	23
1	2409	1
1	2409	2
1	2409	5
1	2409	6
1	2409	7
1	2409	8
1	2409	9
1	2409	10
1	2409	12
1	2409	16
1	2409	19
1	2409	20
1	2409	21
1	2409	22
1	2409	25
1	2410	1
1	2410	2
1	2410	3
1	2410	4
1	2410	7
1	2410	9
1	2410	10
1	2410	13
1	2410	14
1	2410	16
1	2410	17
1	2410	19
1	2410	20
1	2410	22
1	2410	23
1	2411	1
1	2411	2
1	2411	3
1	2411	4
1	2411	5
1	2411	7
1	2411	8
1	2411	9
1	2411	10
1	2411	12
1	2411	13
1	2411	14
1	2411	17
1	2411	19
1	2411	24
1	2412	1
1	2412	4
1	2412	6
1	2412	7
1	2412	8
1	2412	9
1	2412	11
1	2412	13
1	2412	14
1	2412	15
1	2412	17
1	2412	18
1	2412	19
1	2412	21
1	2412	24
1	2413	1
1	2413	3
1	2413	4
1	2413	5
1	2413	6
1	2413	7
1	2413	8
1	2413	9
1	2413	12
1	2413	15
1	2413	16
1	2413	18
1	2413	20
1	2413	21
1	2413	25
1	2414	3
1	2414	4
1	2414	5
1	2414	6
1	2414	7
1	2414	8
1	2414	9
1	2414	10
1	2414	11
1	2414	13
1	2414	16
1	2414	17
1	2414	19
1	2414	21
1	2414	24
1	2415	2
1	2415	6
1	2415	7
1	2415	9
1	2415	10
1	2415	11
1	2415	12
1	2415	13
1	2415	14
1	2415	19
1	2415	20
1	2415	21
1	2415	22
1	2415	23
1	2415	25
1	2416	4
1	2416	5
1	2416	6
1	2416	7
1	2416	11
1	2416	13
1	2416	14
1	2416	15
1	2416	16
1	2416	17
1	2416	18
1	2416	20
1	2416	21
1	2416	22
1	2416	25
1	2417	1
1	2417	4
1	2417	6
1	2417	7
1	2417	8
1	2417	9
1	2417	10
1	2417	11
1	2417	14
1	2417	15
1	2417	17
1	2417	18
1	2417	22
1	2417	23
1	2417	25
1	2418	3
1	2418	4
1	2418	7
1	2418	8
1	2418	11
1	2418	12
1	2418	13
1	2418	14
1	2418	16
1	2418	17
1	2418	18
1	2418	19
1	2418	20
1	2418	23
1	2418	24
1	2419	2
1	2419	3
1	2419	5
1	2419	6
1	2419	10
1	2419	11
1	2419	12
1	2419	13
1	2419	15
1	2419	18
1	2419	19
1	2419	21
1	2419	22
1	2419	23
1	2419	24
1	2420	1
1	2420	3
1	2420	5
1	2420	9
1	2420	10
1	2420	11
1	2420	12
1	2420	13
1	2420	14
1	2420	15
1	2420	18
1	2420	21
1	2420	22
1	2420	24
1	2420	25
1	2421	3
1	2421	4
1	2421	5
1	2421	6
1	2421	7
1	2421	10
1	2421	13
1	2421	14
1	2421	16
1	2421	17
1	2421	19
1	2421	20
1	2421	21
1	2421	22
1	2421	24
1	2422	1
1	2422	2
1	2422	3
1	2422	4
1	2422	5
1	2422	7
1	2422	8
1	2422	10
1	2422	11
1	2422	12
1	2422	14
1	2422	17
1	2422	18
1	2422	22
1	2422	25
1	2423	3
1	2423	4
1	2423	5
1	2423	7
1	2423	8
1	2423	9
1	2423	10
1	2423	11
1	2423	15
1	2423	16
1	2423	17
1	2423	18
1	2423	19
1	2423	20
1	2423	24
1	2424	1
1	2424	3
1	2424	4
1	2424	5
1	2424	6
1	2424	9
1	2424	10
1	2424	11
1	2424	14
1	2424	15
1	2424	16
1	2424	20
1	2424	22
1	2424	23
1	2424	25
1	2425	1
1	2425	3
1	2425	4
1	2425	5
1	2425	6
1	2425	10
1	2425	11
1	2425	13
1	2425	15
1	2425	19
1	2425	20
1	2425	21
1	2425	22
1	2425	24
1	2425	25
1	2426	1
1	2426	2
1	2426	3
1	2426	6
1	2426	7
1	2426	8
1	2426	9
1	2426	11
1	2426	13
1	2426	19
1	2426	20
1	2426	21
1	2426	22
1	2426	23
1	2426	24
1	2427	1
1	2427	3
1	2427	6
1	2427	8
1	2427	11
1	2427	15
1	2427	16
1	2427	17
1	2427	18
1	2427	19
1	2427	20
1	2427	21
1	2427	22
1	2427	23
1	2427	24
1	2428	2
1	2428	5
1	2428	6
1	2428	7
1	2428	9
1	2428	10
1	2428	11
1	2428	12
1	2428	15
1	2428	16
1	2428	17
1	2428	18
1	2428	20
1	2428	24
1	2428	25
1	2429	1
1	2429	4
1	2429	5
1	2429	6
1	2429	8
1	2429	9
1	2429	10
1	2429	11
1	2429	12
1	2429	14
1	2429	15
1	2429	19
1	2429	20
1	2429	21
1	2429	24
1	2430	1
1	2430	4
1	2430	5
1	2430	7
1	2430	8
1	2430	10
1	2430	11
1	2430	12
1	2430	14
1	2430	17
1	2430	18
1	2430	19
1	2430	20
1	2430	21
1	2430	23
1	2431	4
1	2431	6
1	2431	7
1	2431	8
1	2431	9
1	2431	10
1	2431	11
1	2431	12
1	2431	13
1	2431	14
1	2431	17
1	2431	18
1	2431	19
1	2431	22
1	2431	25
1	2432	3
1	2432	5
1	2432	6
1	2432	7
1	2432	8
1	2432	9
1	2432	11
1	2432	12
1	2432	13
1	2432	14
1	2432	15
1	2432	19
1	2432	20
1	2432	21
1	2432	25
1	2433	1
1	2433	3
1	2433	4
1	2433	5
1	2433	6
1	2433	9
1	2433	10
1	2433	11
1	2433	12
1	2433	13
1	2433	15
1	2433	18
1	2433	20
1	2433	21
1	2433	24
1	2434	1
1	2434	4
1	2434	7
1	2434	11
1	2434	13
1	2434	14
1	2434	16
1	2434	17
1	2434	19
1	2434	20
1	2434	21
1	2434	22
1	2434	23
1	2434	24
1	2434	25
1	2435	2
1	2435	4
1	2435	5
1	2435	6
1	2435	7
1	2435	10
1	2435	11
1	2435	12
1	2435	13
1	2435	15
1	2435	16
1	2435	19
1	2435	20
1	2435	21
1	2435	22
1	2436	2
1	2436	3
1	2436	4
1	2436	6
1	2436	8
1	2436	9
1	2436	12
1	2436	14
1	2436	15
1	2436	16
1	2436	17
1	2436	19
1	2436	20
1	2436	21
1	2436	23
1	2437	1
1	2437	2
1	2437	7
1	2437	8
1	2437	9
1	2437	10
1	2437	11
1	2437	13
1	2437	14
1	2437	15
1	2437	17
1	2437	18
1	2437	20
1	2437	21
1	2437	25
1	2438	1
1	2438	4
1	2438	5
1	2438	6
1	2438	8
1	2438	11
1	2438	12
1	2438	13
1	2438	14
1	2438	16
1	2438	18
1	2438	19
1	2438	22
1	2438	23
1	2438	24
1	2439	2
1	2439	5
1	2439	7
1	2439	8
1	2439	9
1	2439	10
1	2439	11
1	2439	13
1	2439	15
1	2439	16
1	2439	17
1	2439	20
1	2439	21
1	2439	23
1	2439	25
1	2440	3
1	2440	4
1	2440	5
1	2440	6
1	2440	8
1	2440	9
1	2440	11
1	2440	14
1	2440	16
1	2440	18
1	2440	20
1	2440	21
1	2440	22
1	2440	24
1	2440	25
1	2441	1
1	2441	3
1	2441	7
1	2441	8
1	2441	9
1	2441	10
1	2441	11
1	2441	13
1	2441	15
1	2441	18
1	2441	20
1	2441	21
1	2441	22
1	2441	24
1	2441	25
1	2442	1
1	2442	6
1	2442	7
1	2442	10
1	2442	11
1	2442	12
1	2442	14
1	2442	15
1	2442	16
1	2442	17
1	2442	18
1	2442	19
1	2442	21
1	2442	22
1	2442	25
1	2443	2
1	2443	3
1	2443	5
1	2443	6
1	2443	7
1	2443	9
1	2443	10
1	2443	14
1	2443	15
1	2443	16
1	2443	17
1	2443	20
1	2443	21
1	2443	22
1	2443	23
1	2444	3
1	2444	4
1	2444	5
1	2444	6
1	2444	8
1	2444	9
1	2444	10
1	2444	11
1	2444	12
1	2444	14
1	2444	16
1	2444	17
1	2444	18
1	2444	19
1	2444	25
1	2445	1
1	2445	2
1	2445	5
1	2445	6
1	2445	7
1	2445	8
1	2445	10
1	2445	11
1	2445	13
1	2445	15
1	2445	18
1	2445	21
1	2445	22
1	2445	23
1	2445	25
1	2446	4
1	2446	6
1	2446	8
1	2446	11
1	2446	12
1	2446	13
1	2446	15
1	2446	17
1	2446	19
1	2446	20
1	2446	21
1	2446	22
1	2446	23
1	2446	24
1	2446	25
1	2447	2
1	2447	3
1	2447	4
1	2447	5
1	2447	8
1	2447	13
1	2447	14
1	2447	15
1	2447	16
1	2447	17
1	2447	18
1	2447	19
1	2447	20
1	2447	22
1	2447	23
1	2448	2
1	2448	3
1	2448	4
1	2448	5
1	2448	6
1	2448	8
1	2448	9
1	2448	11
1	2448	12
1	2448	14
1	2448	16
1	2448	19
1	2448	20
1	2448	22
1	2448	24
1	2449	1
1	2449	2
1	2449	4
1	2449	8
1	2449	9
1	2449	11
1	2449	13
1	2449	14
1	2449	15
1	2449	16
1	2449	17
1	2449	18
1	2449	20
1	2449	21
1	2449	22
1	2450	1
1	2450	2
1	2450	3
1	2450	4
1	2450	5
1	2450	7
1	2450	8
1	2450	11
1	2450	13
1	2450	14
1	2450	15
1	2450	18
1	2450	23
1	2450	24
1	2450	25
1	2451	3
1	2451	4
1	2451	5
1	2451	7
1	2451	9
1	2451	10
1	2451	11
1	2451	15
1	2451	18
1	2451	19
1	2451	20
1	2451	22
1	2451	23
1	2451	24
1	2451	25
1	2452	1
1	2452	6
1	2452	7
1	2452	8
1	2452	9
1	2452	11
1	2452	15
1	2452	17
1	2452	18
1	2452	20
1	2452	21
1	2452	22
1	2452	23
1	2452	24
1	2452	25
1	2453	4
1	2453	5
1	2453	7
1	2453	8
1	2453	10
1	2453	12
1	2453	13
1	2453	16
1	2453	17
1	2453	19
1	2453	21
1	2453	22
1	2453	23
1	2453	24
1	2453	25
1	2454	1
1	2454	2
1	2454	4
1	2454	6
1	2454	8
1	2454	9
1	2454	10
1	2454	12
1	2454	15
1	2454	16
1	2454	20
1	2454	21
1	2454	23
1	2454	24
1	2454	25
1	2455	1
1	2455	2
1	2455	3
1	2455	8
1	2455	10
1	2455	11
1	2455	12
1	2455	13
1	2455	14
1	2455	16
1	2455	19
1	2455	22
1	2455	23
1	2455	24
1	2455	25
1	2456	4
1	2456	5
1	2456	6
1	2456	8
1	2456	9
1	2456	10
1	2456	12
1	2456	13
1	2456	14
1	2456	17
1	2456	18
1	2456	19
1	2456	21
1	2456	24
1	2456	25
1	2457	1
1	2457	3
1	2457	5
1	2457	8
1	2457	10
1	2457	11
1	2457	14
1	2457	15
1	2457	16
1	2457	18
1	2457	20
1	2457	22
1	2457	23
1	2457	24
1	2457	25
1	2458	1
1	2458	2
1	2458	3
1	2458	4
1	2458	6
1	2458	8
1	2458	10
1	2458	11
1	2458	12
1	2458	16
1	2458	18
1	2458	21
1	2458	22
1	2458	24
1	2458	25
1	2459	1
1	2459	3
1	2459	5
1	2459	6
1	2459	11
1	2459	12
1	2459	14
1	2459	15
1	2459	17
1	2459	18
1	2459	19
1	2459	20
1	2459	21
1	2459	23
1	2459	25
1	2460	1
1	2460	2
1	2460	3
1	2460	4
1	2460	5
1	2460	6
1	2460	9
1	2460	11
1	2460	12
1	2460	14
1	2460	15
1	2460	18
1	2460	19
1	2460	23
1	2460	25
1	2461	1
1	2461	2
1	2461	5
1	2461	7
1	2461	10
1	2461	13
1	2461	14
1	2461	15
1	2461	17
1	2461	18
1	2461	19
1	2461	20
1	2461	21
1	2461	22
1	2461	24
1	2462	3
1	2462	4
1	2462	5
1	2462	9
1	2462	10
1	2462	11
1	2462	12
1	2462	14
1	2462	15
1	2462	16
1	2462	17
1	2462	18
1	2462	20
1	2462	22
1	2462	25
1	2463	5
1	2463	7
1	2463	9
1	2463	10
1	2463	11
1	2463	12
1	2463	13
1	2463	14
1	2463	15
1	2463	17
1	2463	18
1	2463	20
1	2463	21
1	2463	23
1	2463	25
1	2464	1
1	2464	5
1	2464	6
1	2464	7
1	2464	9
1	2464	11
1	2464	13
1	2464	16
1	2464	17
1	2464	20
1	2464	21
1	2464	22
1	2464	23
1	2464	24
1	2464	25
1	2465	2
1	2465	5
1	2465	6
1	2465	7
1	2465	8
1	2465	10
1	2465	11
1	2465	13
1	2465	14
1	2465	15
1	2465	17
1	2465	18
1	2465	19
1	2465	21
1	2465	25
1	2466	1
1	2466	2
1	2466	5
1	2466	7
1	2466	8
1	2466	9
1	2466	12
1	2466	13
1	2466	14
1	2466	17
1	2466	19
1	2466	20
1	2466	21
1	2466	24
1	2466	25
1	2467	5
1	2467	6
1	2467	8
1	2467	10
1	2467	11
1	2467	12
1	2467	14
1	2467	15
1	2467	16
1	2467	18
1	2467	20
1	2467	21
1	2467	22
1	2467	23
1	2467	25
1	2468	3
1	2468	4
1	2468	7
1	2468	8
1	2468	9
1	2468	12
1	2468	13
1	2468	17
1	2468	18
1	2468	19
1	2468	20
1	2468	21
1	2468	22
1	2468	23
1	2468	24
1	2469	1
1	2469	2
1	2469	4
1	2469	5
1	2469	6
1	2469	7
1	2469	11
1	2469	13
1	2469	17
1	2469	18
1	2469	19
1	2469	20
1	2469	21
1	2469	24
1	2469	25
1	2470	1
1	2470	3
1	2470	4
1	2470	5
1	2470	6
1	2470	9
1	2470	10
1	2470	11
1	2470	12
1	2470	13
1	2470	21
1	2470	22
1	2470	23
1	2470	24
1	2470	25
1	2471	2
1	2471	3
1	2471	4
1	2471	5
1	2471	8
1	2471	9
1	2471	14
1	2471	17
1	2471	18
1	2471	19
1	2471	20
1	2471	21
1	2471	23
1	2471	24
1	2471	25
1	2472	2
1	2472	3
1	2472	4
1	2472	9
1	2472	10
1	2472	12
1	2472	13
1	2472	15
1	2472	16
1	2472	17
1	2472	21
1	2472	22
1	2472	23
1	2472	24
1	2472	25
1	2473	1
1	2473	4
1	2473	6
1	2473	7
1	2473	8
1	2473	9
1	2473	10
1	2473	14
1	2473	16
1	2473	18
1	2473	19
1	2473	20
1	2473	21
1	2473	23
1	2473	25
1	2474	1
1	2474	2
1	2474	5
1	2474	6
1	2474	8
1	2474	9
1	2474	11
1	2474	14
1	2474	15
1	2474	17
1	2474	19
1	2474	20
1	2474	23
1	2474	24
1	2474	25
1	2475	1
1	2475	3
1	2475	4
1	2475	5
1	2475	6
1	2475	7
1	2475	11
1	2475	13
1	2475	15
1	2475	16
1	2475	18
1	2475	19
1	2475	22
1	2475	24
1	2475	25
1	2476	1
1	2476	6
1	2476	9
1	2476	10
1	2476	11
1	2476	12
1	2476	13
1	2476	15
1	2476	16
1	2476	17
1	2476	18
1	2476	21
1	2476	22
1	2476	23
1	2476	24
1	2477	1
1	2477	2
1	2477	3
1	2477	5
1	2477	7
1	2477	8
1	2477	9
1	2477	10
1	2477	13
1	2477	14
1	2477	15
1	2477	18
1	2477	19
1	2477	20
1	2477	24
1	2478	1
1	2478	5
1	2478	7
1	2478	8
1	2478	10
1	2478	11
1	2478	12
1	2478	14
1	2478	15
1	2478	16
1	2478	21
1	2478	22
1	2478	23
1	2478	24
1	2478	25
1	2479	2
1	2479	3
1	2479	4
1	2479	5
1	2479	7
1	2479	11
1	2479	12
1	2479	14
1	2479	17
1	2479	19
1	2479	20
1	2479	21
1	2479	23
1	2479	24
1	2479	25
1	2480	1
1	2480	2
1	2480	5
1	2480	6
1	2480	7
1	2480	9
1	2480	10
1	2480	12
1	2480	13
1	2480	14
1	2480	15
1	2480	16
1	2480	17
1	2480	21
1	2480	24
1	2481	2
1	2481	3
1	2481	5
1	2481	6
1	2481	7
1	2481	9
1	2481	10
1	2481	13
1	2481	14
1	2481	15
1	2481	17
1	2481	18
1	2481	20
1	2481	21
1	2481	25
1	2482	3
1	2482	5
1	2482	6
1	2482	7
1	2482	9
1	2482	11
1	2482	12
1	2482	13
1	2482	14
1	2482	16
1	2482	17
1	2482	20
1	2482	21
1	2482	24
1	2482	25
1	2483	2
1	2483	3
1	2483	6
1	2483	7
1	2483	8
1	2483	10
1	2483	13
1	2483	14
1	2483	15
1	2483	16
1	2483	19
1	2483	20
1	2483	22
1	2483	23
1	2483	25
1	2484	4
1	2484	5
1	2484	6
1	2484	8
1	2484	10
1	2484	11
1	2484	12
1	2484	14
1	2484	15
1	2484	17
1	2484	19
1	2484	21
1	2484	22
1	2484	23
1	2484	25
1	2485	1
1	2485	2
1	2485	3
1	2485	8
1	2485	10
1	2485	12
1	2485	14
1	2485	15
1	2485	17
1	2485	18
1	2485	20
1	2485	21
1	2485	23
1	2485	24
1	2485	25
1	2486	1
1	2486	2
1	2486	4
1	2486	5
1	2486	8
1	2486	9
1	2486	10
1	2486	11
1	2486	12
1	2486	18
1	2486	19
1	2486	20
1	2486	23
1	2486	24
1	2486	25
1	2487	1
1	2487	2
1	2487	6
1	2487	8
1	2487	10
1	2487	11
1	2487	12
1	2487	13
1	2487	14
1	2487	16
1	2487	18
1	2487	20
1	2487	22
1	2487	23
1	2487	24
1	2488	1
1	2488	2
1	2488	4
1	2488	5
1	2488	6
1	2488	7
1	2488	9
1	2488	11
1	2488	12
1	2488	13
1	2488	16
1	2488	20
1	2488	21
1	2488	22
1	2488	24
1	2489	1
1	2489	4
1	2489	5
1	2489	7
1	2489	8
1	2489	10
1	2489	11
1	2489	13
1	2489	14
1	2489	16
1	2489	18
1	2489	21
1	2489	22
1	2489	23
1	2489	24
1	2490	1
1	2490	3
1	2490	4
1	2490	5
1	2490	6
1	2490	10
1	2490	12
1	2490	13
1	2490	14
1	2490	15
1	2490	16
1	2490	19
1	2490	20
1	2490	24
1	2490	25
1	2491	1
1	2491	2
1	2491	3
1	2491	4
1	2491	5
1	2491	6
1	2491	9
1	2491	11
1	2491	14
1	2491	17
1	2491	18
1	2491	19
1	2491	21
1	2491	22
1	2491	24
1	2492	4
1	2492	7
1	2492	8
1	2492	9
1	2492	10
1	2492	11
1	2492	12
1	2492	13
1	2492	14
1	2492	15
1	2492	17
1	2492	20
1	2492	22
1	2492	23
1	2492	24
1	2493	2
1	2493	3
1	2493	6
1	2493	7
1	2493	9
1	2493	10
1	2493	11
1	2493	12
1	2493	14
1	2493	15
1	2493	16
1	2493	18
1	2493	20
1	2493	21
1	2493	25
1	2494	1
1	2494	2
1	2494	4
1	2494	5
1	2494	6
1	2494	8
1	2494	9
1	2494	10
1	2494	12
1	2494	13
1	2494	16
1	2494	18
1	2494	23
1	2494	24
1	2494	25
1	2495	3
1	2495	5
1	2495	9
1	2495	10
1	2495	12
1	2495	13
1	2495	14
1	2495	15
1	2495	16
1	2495	17
1	2495	18
1	2495	19
1	2495	21
1	2495	24
1	2495	25
1	2496	2
1	2496	3
1	2496	4
1	2496	8
1	2496	9
1	2496	10
1	2496	11
1	2496	13
1	2496	17
1	2496	18
1	2496	20
1	2496	22
1	2496	23
1	2496	24
1	2496	25
1	2497	2
1	2497	6
1	2497	7
1	2497	8
1	2497	9
1	2497	11
1	2497	12
1	2497	14
1	2497	15
1	2497	18
1	2497	19
1	2497	20
1	2497	22
1	2497	23
1	2497	25
1	2498	1
1	2498	2
1	2498	5
1	2498	6
1	2498	7
1	2498	8
1	2498	9
1	2498	11
1	2498	12
1	2498	17
1	2498	18
1	2498	19
1	2498	20
1	2498	22
1	2498	25
1	2499	2
1	2499	3
1	2499	4
1	2499	5
1	2499	7
1	2499	8
1	2499	11
1	2499	12
1	2499	14
1	2499	16
1	2499	17
1	2499	19
1	2499	20
1	2499	22
1	2499	23
1	2500	3
1	2500	4
1	2500	5
1	2500	6
1	2500	9
1	2500	11
1	2500	12
1	2500	13
1	2500	14
1	2500	15
1	2500	17
1	2500	18
1	2500	19
1	2500	21
1	2500	25
1	2501	1
1	2501	2
1	2501	3
1	2501	4
1	2501	5
1	2501	6
1	2501	7
1	2501	8
1	2501	9
1	2501	11
1	2501	19
1	2501	20
1	2501	22
1	2501	23
1	2501	25
1	2502	2
1	2502	3
1	2502	4
1	2502	5
1	2502	9
1	2502	11
1	2502	12
1	2502	13
1	2502	15
1	2502	18
1	2502	20
1	2502	21
1	2502	23
1	2502	24
1	2502	25
1	2503	1
1	2503	2
1	2503	3
1	2503	4
1	2503	6
1	2503	7
1	2503	9
1	2503	10
1	2503	11
1	2503	12
1	2503	13
1	2503	18
1	2503	19
1	2503	20
1	2503	22
1	2504	3
1	2504	5
1	2504	7
1	2504	8
1	2504	12
1	2504	13
1	2504	14
1	2504	15
1	2504	16
1	2504	17
1	2504	20
1	2504	21
1	2504	22
1	2504	23
1	2504	24
1	2505	1
1	2505	2
1	2505	3
1	2505	4
1	2505	6
1	2505	8
1	2505	9
1	2505	10
1	2505	17
1	2505	18
1	2505	19
1	2505	21
1	2505	23
1	2505	24
1	2505	25
1	2506	3
1	2506	4
1	2506	5
1	2506	8
1	2506	9
1	2506	10
1	2506	11
1	2506	14
1	2506	15
1	2506	16
1	2506	18
1	2506	19
1	2506	20
1	2506	22
1	2506	25
1	2507	3
1	2507	4
1	2507	5
1	2507	7
1	2507	8
1	2507	9
1	2507	10
1	2507	11
1	2507	13
1	2507	14
1	2507	15
1	2507	16
1	2507	19
1	2507	20
1	2507	25
1	2508	1
1	2508	2
1	2508	5
1	2508	6
1	2508	7
1	2508	10
1	2508	11
1	2508	12
1	2508	14
1	2508	15
1	2508	17
1	2508	18
1	2508	19
1	2508	20
1	2508	21
1	2509	2
1	2509	3
1	2509	4
1	2509	5
1	2509	9
1	2509	10
1	2509	11
1	2509	12
1	2509	13
1	2509	14
1	2509	19
1	2509	21
1	2509	22
1	2509	23
1	2509	25
1	2510	1
1	2510	2
1	2510	5
1	2510	7
1	2510	11
1	2510	13
1	2510	14
1	2510	16
1	2510	17
1	2510	19
1	2510	20
1	2510	22
1	2510	23
1	2510	24
1	2510	25
1	2511	1
1	2511	3
1	2511	4
1	2511	5
1	2511	6
1	2511	8
1	2511	9
1	2511	11
1	2511	15
1	2511	16
1	2511	18
1	2511	21
1	2511	23
1	2511	24
1	2511	25
1	2512	1
1	2512	2
1	2512	3
1	2512	7
1	2512	9
1	2512	10
1	2512	12
1	2512	14
1	2512	15
1	2512	16
1	2512	18
1	2512	19
1	2512	20
1	2512	21
1	2512	23
1	2513	2
1	2513	3
1	2513	4
1	2513	6
1	2513	7
1	2513	9
1	2513	11
1	2513	12
1	2513	16
1	2513	17
1	2513	19
1	2513	20
1	2513	21
1	2513	23
1	2513	24
1	2514	2
1	2514	3
1	2514	5
1	2514	6
1	2514	7
1	2514	8
1	2514	9
1	2514	12
1	2514	14
1	2514	15
1	2514	16
1	2514	18
1	2514	19
1	2514	21
1	2514	24
1	2515	4
1	2515	5
1	2515	7
1	2515	8
1	2515	9
1	2515	11
1	2515	12
1	2515	14
1	2515	15
1	2515	16
1	2515	19
1	2515	21
1	2515	22
1	2515	24
1	2515	25
1	2516	1
1	2516	2
1	2516	3
1	2516	5
1	2516	7
1	2516	8
1	2516	10
1	2516	11
1	2516	14
1	2516	15
1	2516	16
1	2516	17
1	2516	21
1	2516	22
1	2516	24
1	2517	1
1	2517	2
1	2517	3
1	2517	5
1	2517	6
1	2517	9
1	2517	10
1	2517	12
1	2517	14
1	2517	15
1	2517	16
1	2517	20
1	2517	21
1	2517	23
1	2517	24
1	2518	1
1	2518	2
1	2518	4
1	2518	5
1	2518	6
1	2518	8
1	2518	11
1	2518	13
1	2518	14
1	2518	15
1	2518	20
1	2518	22
1	2518	23
1	2518	24
1	2518	25
1	2519	2
1	2519	3
1	2519	4
1	2519	5
1	2519	8
1	2519	10
1	2519	11
1	2519	12
1	2519	13
1	2519	14
1	2519	18
1	2519	19
1	2519	22
1	2519	24
1	2519	25
1	2520	1
1	2520	2
1	2520	4
1	2520	5
1	2520	6
1	2520	7
1	2520	8
1	2520	10
1	2520	14
1	2520	15
1	2520	16
1	2520	18
1	2520	23
1	2520	24
1	2520	25
1	2521	2
1	2521	3
1	2521	4
1	2521	6
1	2521	7
1	2521	8
1	2521	13
1	2521	14
1	2521	16
1	2521	17
1	2521	18
1	2521	21
1	2521	22
1	2521	24
1	2521	25
1	2522	1
1	2522	2
1	2522	3
1	2522	5
1	2522	9
1	2522	10
1	2522	12
1	2522	13
1	2522	15
1	2522	16
1	2522	18
1	2522	19
1	2522	21
1	2522	22
1	2522	25
1	2523	1
1	2523	4
1	2523	5
1	2523	6
1	2523	7
1	2523	10
1	2523	11
1	2523	12
1	2523	14
1	2523	15
1	2523	17
1	2523	18
1	2523	20
1	2523	23
1	2523	24
1	2524	1
1	2524	2
1	2524	3
1	2524	5
1	2524	6
1	2524	7
1	2524	12
1	2524	14
1	2524	15
1	2524	16
1	2524	19
1	2524	20
1	2524	23
1	2524	24
1	2524	25
1	2525	4
1	2525	6
1	2525	10
1	2525	11
1	2525	12
1	2525	13
1	2525	16
1	2525	17
1	2525	18
1	2525	19
1	2525	20
1	2525	21
1	2525	23
1	2525	24
1	2525	25
1	2526	1
1	2526	2
1	2526	6
1	2526	8
1	2526	11
1	2526	12
1	2526	13
1	2526	14
1	2526	16
1	2526	17
1	2526	19
1	2526	20
1	2526	22
1	2526	23
1	2526	24
1	2527	1
1	2527	2
1	2527	5
1	2527	6
1	2527	9
1	2527	11
1	2527	12
1	2527	13
1	2527	14
1	2527	17
1	2527	18
1	2527	19
1	2527	20
1	2527	21
1	2527	23
1	2528	2
1	2528	3
1	2528	5
1	2528	7
1	2528	8
1	2528	9
1	2528	10
1	2528	11
1	2528	12
1	2528	13
1	2528	15
1	2528	20
1	2528	22
1	2528	23
1	2528	24
1	2529	3
1	2529	5
1	2529	6
1	2529	8
1	2529	9
1	2529	11
1	2529	12
1	2529	13
1	2529	14
1	2529	16
1	2529	18
1	2529	21
1	2529	22
1	2529	24
1	2529	25
1	2530	1
1	2530	2
1	2530	4
1	2530	6
1	2530	7
1	2530	8
1	2530	9
1	2530	11
1	2530	13
1	2530	15
1	2530	21
1	2530	22
1	2530	23
1	2530	24
1	2530	25
1	2531	1
1	2531	2
1	2531	3
1	2531	4
1	2531	5
1	2531	7
1	2531	8
1	2531	11
1	2531	12
1	2531	16
1	2531	17
1	2531	18
1	2531	20
1	2531	21
1	2531	25
1	2532	1
1	2532	2
1	2532	3
1	2532	4
1	2532	6
1	2532	9
1	2532	10
1	2532	12
1	2532	13
1	2532	14
1	2532	16
1	2532	17
1	2532	18
1	2532	22
1	2532	25
1	2533	4
1	2533	7
1	2533	8
1	2533	10
1	2533	11
1	2533	12
1	2533	15
1	2533	16
1	2533	17
1	2533	18
1	2533	19
1	2533	22
1	2533	23
1	2533	24
1	2533	25
1	2534	7
1	2534	8
1	2534	10
1	2534	11
1	2534	12
1	2534	14
1	2534	15
1	2534	16
1	2534	17
1	2534	18
1	2534	20
1	2534	21
1	2534	22
1	2534	23
1	2534	25
1	2535	5
1	2535	6
1	2535	7
1	2535	8
1	2535	11
1	2535	12
1	2535	13
1	2535	14
1	2535	15
1	2535	16
1	2535	18
1	2535	20
1	2535	22
1	2535	24
1	2535	25
1	2536	1
1	2536	2
1	2536	4
1	2536	6
1	2536	9
1	2536	12
1	2536	13
1	2536	15
1	2536	16
1	2536	17
1	2536	18
1	2536	19
1	2536	21
1	2536	23
1	2536	25
1	2537	2
1	2537	4
1	2537	5
1	2537	6
1	2537	7
1	2537	9
1	2537	10
1	2537	12
1	2537	14
1	2537	16
1	2537	18
1	2537	19
1	2537	22
1	2537	23
1	2537	24
1	2538	1
1	2538	2
1	2538	4
1	2538	5
1	2538	6
1	2538	8
1	2538	9
1	2538	13
1	2538	14
1	2538	16
1	2538	17
1	2538	21
1	2538	22
1	2538	24
1	2538	25
1	2539	1
1	2539	3
1	2539	4
1	2539	5
1	2539	6
1	2539	9
1	2539	10
1	2539	13
1	2539	16
1	2539	17
1	2539	18
1	2539	20
1	2539	23
1	2539	24
1	2539	25
1	2540	1
1	2540	3
1	2540	5
1	2540	6
1	2540	7
1	2540	8
1	2540	11
1	2540	12
1	2540	14
1	2540	18
1	2540	20
1	2540	21
1	2540	22
1	2540	23
1	2540	24
1	2541	2
1	2541	4
1	2541	7
1	2541	8
1	2541	11
1	2541	12
1	2541	13
1	2541	14
1	2541	16
1	2541	17
1	2541	18
1	2541	19
1	2541	20
1	2541	22
1	2541	25
1	2542	3
1	2542	5
1	2542	8
1	2542	10
1	2542	12
1	2542	13
1	2542	15
1	2542	16
1	2542	18
1	2542	19
1	2542	20
1	2542	21
1	2542	22
1	2542	24
1	2542	25
1	2543	3
1	2543	5
1	2543	6
1	2543	7
1	2543	8
1	2543	9
1	2543	11
1	2543	12
1	2543	14
1	2543	17
1	2543	18
1	2543	19
1	2543	20
1	2543	24
1	2543	25
1	2544	3
1	2544	5
1	2544	6
1	2544	7
1	2544	8
1	2544	10
1	2544	11
1	2544	12
1	2544	13
1	2544	15
1	2544	18
1	2544	20
1	2544	21
1	2544	23
1	2544	24
1	2545	1
1	2545	2
1	2545	3
1	2545	5
1	2545	7
1	2545	9
1	2545	10
1	2545	13
1	2545	14
1	2545	15
1	2545	16
1	2545	19
1	2545	20
1	2545	21
1	2545	24
1	2546	2
1	2546	4
1	2546	5
1	2546	7
1	2546	8
1	2546	9
1	2546	10
1	2546	11
1	2546	14
1	2546	17
1	2546	20
1	2546	21
1	2546	22
1	2546	24
1	2546	25
1	2547	1
1	2547	2
1	2547	5
1	2547	9
1	2547	10
1	2547	12
1	2547	15
1	2547	16
1	2547	18
1	2547	19
1	2547	21
1	2547	22
1	2547	23
1	2547	24
1	2547	25
1	2548	1
1	2548	2
1	2548	3
1	2548	4
1	2548	5
1	2548	8
1	2548	9
1	2548	11
1	2548	13
1	2548	15
1	2548	16
1	2548	18
1	2548	19
1	2548	23
1	2548	25
1	2549	1
1	2549	2
1	2549	4
1	2549	5
1	2549	6
1	2549	7
1	2549	9
1	2549	11
1	2549	16
1	2549	17
1	2549	19
1	2549	21
1	2549	22
1	2549	24
1	2549	25
1	2550	1
1	2550	2
1	2550	6
1	2550	7
1	2550	9
1	2550	10
1	2550	12
1	2550	13
1	2550	17
1	2550	18
1	2550	20
1	2550	21
1	2550	23
1	2550	24
1	2550	25
1	2551	1
1	2551	2
1	2551	6
1	2551	9
1	2551	10
1	2551	11
1	2551	12
1	2551	14
1	2551	15
1	2551	16
1	2551	18
1	2551	20
1	2551	21
1	2551	22
1	2551	25
1	2552	1
1	2552	3
1	2552	4
1	2552	5
1	2552	9
1	2552	10
1	2552	12
1	2552	13
1	2552	14
1	2552	15
1	2552	17
1	2552	18
1	2552	21
1	2552	24
1	2552	25
1	2553	1
1	2553	2
1	2553	4
1	2553	5
1	2553	7
1	2553	8
1	2553	9
1	2553	11
1	2553	13
1	2553	14
1	2553	17
1	2553	18
1	2553	19
1	2553	21
1	2553	25
1	2554	2
1	2554	3
1	2554	4
1	2554	8
1	2554	10
1	2554	11
1	2554	13
1	2554	15
1	2554	16
1	2554	17
1	2554	18
1	2554	19
1	2554	20
1	2554	22
1	2554	24
1	2555	2
1	2555	3
1	2555	4
1	2555	6
1	2555	7
1	2555	8
1	2555	11
1	2555	12
1	2555	16
1	2555	17
1	2555	18
1	2555	21
1	2555	22
1	2555	23
1	2555	25
1	2556	1
1	2556	2
1	2556	5
1	2556	10
1	2556	11
1	2556	12
1	2556	15
1	2556	17
1	2556	18
1	2556	20
1	2556	21
1	2556	22
1	2556	23
1	2556	24
1	2556	25
1	2557	2
1	2557	3
1	2557	4
1	2557	5
1	2557	6
1	2557	7
1	2557	8
1	2557	9
1	2557	10
1	2557	11
1	2557	12
1	2557	17
1	2557	18
1	2557	21
1	2557	22
1	2558	3
1	2558	4
1	2558	5
1	2558	6
1	2558	10
1	2558	12
1	2558	14
1	2558	15
1	2558	16
1	2558	17
1	2558	20
1	2558	21
1	2558	22
1	2558	24
1	2558	25
1	2559	1
1	2559	3
1	2559	5
1	2559	7
1	2559	8
1	2559	9
1	2559	10
1	2559	12
1	2559	13
1	2559	14
1	2559	16
1	2559	17
1	2559	19
1	2559	21
1	2559	25
1	2560	1
1	2560	2
1	2560	4
1	2560	5
1	2560	6
1	2560	8
1	2560	9
1	2560	11
1	2560	14
1	2560	16
1	2560	18
1	2560	20
1	2560	23
1	2560	24
1	2560	25
1	2561	1
1	2561	2
1	2561	3
1	2561	5
1	2561	6
1	2561	7
1	2561	12
1	2561	13
1	2561	15
1	2561	16
1	2561	17
1	2561	18
1	2561	20
1	2561	21
1	2561	23
1	2562	2
1	2562	3
1	2562	6
1	2562	7
1	2562	9
1	2562	10
1	2562	11
1	2562	14
1	2562	16
1	2562	17
1	2562	20
1	2562	21
1	2562	22
1	2562	24
1	2562	25
1	2563	3
1	2563	4
1	2563	6
1	2563	8
1	2563	9
1	2563	12
1	2563	15
1	2563	17
1	2563	18
1	2563	19
1	2563	21
1	2563	22
1	2563	23
1	2563	24
1	2563	25
1	2564	2
1	2564	4
1	2564	6
1	2564	7
1	2564	8
1	2564	11
1	2564	15
1	2564	16
1	2564	17
1	2564	18
1	2564	21
1	2564	22
1	2564	23
1	2564	24
1	2564	25
1	2565	1
1	2565	2
1	2565	5
1	2565	7
1	2565	9
1	2565	10
1	2565	11
1	2565	12
1	2565	14
1	2565	15
1	2565	16
1	2565	18
1	2565	20
1	2565	22
1	2565	25
1	2566	1
1	2566	2
1	2566	10
1	2566	11
1	2566	12
1	2566	13
1	2566	14
1	2566	15
1	2566	16
1	2566	18
1	2566	19
1	2566	20
1	2566	21
1	2566	23
1	2566	24
1	2567	1
1	2567	2
1	2567	3
1	2567	4
1	2567	5
1	2567	7
1	2567	11
1	2567	12
1	2567	13
1	2567	14
1	2567	15
1	2567	19
1	2567	20
1	2567	21
1	2567	24
1	2568	1
1	2568	2
1	2568	4
1	2568	6
1	2568	8
1	2568	9
1	2568	11
1	2568	12
1	2568	14
1	2568	15
1	2568	17
1	2568	20
1	2568	21
1	2568	22
1	2568	24
1	2569	3
1	2569	5
1	2569	12
1	2569	13
1	2569	14
1	2569	15
1	2569	16
1	2569	17
1	2569	18
1	2569	19
1	2569	20
1	2569	21
1	2569	22
1	2569	23
1	2569	25
1	2570	1
1	2570	3
1	2570	4
1	2570	5
1	2570	6
1	2570	7
1	2570	9
1	2570	10
1	2570	11
1	2570	13
1	2570	16
1	2570	18
1	2570	20
1	2570	23
1	2570	25
1	2571	2
1	2571	4
1	2571	5
1	2571	7
1	2571	10
1	2571	14
1	2571	15
1	2571	16
1	2571	17
1	2571	19
1	2571	20
1	2571	21
1	2571	23
1	2571	24
1	2571	25
1	2572	1
1	2572	3
1	2572	5
1	2572	7
1	2572	8
1	2572	9
1	2572	11
1	2572	12
1	2572	13
1	2572	14
1	2572	15
1	2572	16
1	2572	21
1	2572	23
1	2572	24
1	2573	2
1	2573	6
1	2573	9
1	2573	10
1	2573	11
1	2573	12
1	2573	13
1	2573	15
1	2573	16
1	2573	17
1	2573	18
1	2573	19
1	2573	20
1	2573	22
1	2573	23
1	2574	1
1	2574	2
1	2574	3
1	2574	7
1	2574	9
1	2574	10
1	2574	11
1	2574	12
1	2574	14
1	2574	16
1	2574	17
1	2574	19
1	2574	20
1	2574	21
1	2574	25
1	2575	2
1	2575	3
1	2575	5
1	2575	6
1	2575	7
1	2575	8
1	2575	10
1	2575	11
1	2575	14
1	2575	15
1	2575	16
1	2575	17
1	2575	21
1	2575	23
1	2575	25
1	2576	1
1	2576	2
1	2576	5
1	2576	6
1	2576	7
1	2576	10
1	2576	13
1	2576	15
1	2576	16
1	2576	18
1	2576	19
1	2576	20
1	2576	21
1	2576	24
1	2576	25
1	2577	1
1	2577	4
1	2577	6
1	2577	7
1	2577	8
1	2577	9
1	2577	12
1	2577	13
1	2577	14
1	2577	18
1	2577	20
1	2577	21
1	2577	23
1	2577	24
1	2577	25
1	2578	1
1	2578	2
1	2578	3
1	2578	4
1	2578	7
1	2578	8
1	2578	9
1	2578	10
1	2578	12
1	2578	14
1	2578	15
1	2578	16
1	2578	20
1	2578	22
1	2578	25
1	2579	1
1	2579	3
1	2579	4
1	2579	7
1	2579	8
1	2579	10
1	2579	12
1	2579	15
1	2579	16
1	2579	17
1	2579	18
1	2579	19
1	2579	22
1	2579	23
1	2579	25
1	2580	1
1	2580	5
1	2580	7
1	2580	8
1	2580	10
1	2580	11
1	2580	12
1	2580	13
1	2580	14
1	2580	15
1	2580	16
1	2580	18
1	2580	20
1	2580	22
1	2580	25
1	2581	1
1	2581	2
1	2581	3
1	2581	4
1	2581	7
1	2581	8
1	2581	11
1	2581	12
1	2581	15
1	2581	16
1	2581	17
1	2581	19
1	2581	20
1	2581	21
1	2581	22
1	2582	1
1	2582	3
1	2582	4
1	2582	5
1	2582	8
1	2582	10
1	2582	11
1	2582	12
1	2582	13
1	2582	15
1	2582	16
1	2582	18
1	2582	19
1	2582	21
1	2582	24
1	2583	1
1	2583	2
1	2583	5
1	2583	7
1	2583	8
1	2583	10
1	2583	11
1	2583	13
1	2583	14
1	2583	15
1	2583	16
1	2583	18
1	2583	19
1	2583	23
1	2583	24
1	2584	3
1	2584	4
1	2584	5
1	2584	7
1	2584	8
1	2584	10
1	2584	11
1	2584	12
1	2584	13
1	2584	14
1	2584	15
1	2584	16
1	2584	22
1	2584	23
1	2584	24
1	2585	3
1	2585	4
1	2585	6
1	2585	7
1	2585	8
1	2585	10
1	2585	12
1	2585	17
1	2585	18
1	2585	20
1	2585	21
1	2585	22
1	2585	23
1	2585	24
1	2585	25
1	2586	1
1	2586	2
1	2586	7
1	2586	8
1	2586	12
1	2586	13
1	2586	15
1	2586	16
1	2586	18
1	2586	19
1	2586	20
1	2586	21
1	2586	22
1	2586	23
1	2586	24
1	2587	3
1	2587	4
1	2587	6
1	2587	7
1	2587	8
1	2587	9
1	2587	11
1	2587	13
1	2587	15
1	2587	16
1	2587	19
1	2587	20
1	2587	21
1	2587	22
1	2587	24
1	2588	3
1	2588	4
1	2588	5
1	2588	8
1	2588	9
1	2588	10
1	2588	14
1	2588	15
1	2588	17
1	2588	18
1	2588	21
1	2588	22
1	2588	23
1	2588	24
1	2588	25
1	2589	1
1	2589	2
1	2589	4
1	2589	5
1	2589	7
1	2589	8
1	2589	9
1	2589	10
1	2589	14
1	2589	15
1	2589	18
1	2589	21
1	2589	22
1	2589	24
1	2589	25
1	2590	1
1	2590	3
1	2590	4
1	2590	5
1	2590	7
1	2590	9
1	2590	10
1	2590	13
1	2590	15
1	2590	16
1	2590	18
1	2590	20
1	2590	21
1	2590	24
1	2590	25
1	2591	1
1	2591	2
1	2591	3
1	2591	4
1	2591	5
1	2591	7
1	2591	9
1	2591	11
1	2591	12
1	2591	14
1	2591	17
1	2591	20
1	2591	21
1	2591	23
1	2591	24
1	2592	1
1	2592	2
1	2592	4
1	2592	5
1	2592	6
1	2592	7
1	2592	10
1	2592	14
1	2592	15
1	2592	18
1	2592	19
1	2592	21
1	2592	22
1	2592	23
1	2592	25
1	2593	1
1	2593	5
1	2593	6
1	2593	8
1	2593	9
1	2593	10
1	2593	12
1	2593	13
1	2593	15
1	2593	17
1	2593	20
1	2593	21
1	2593	22
1	2593	23
1	2593	24
1	2594	4
1	2594	5
1	2594	9
1	2594	11
1	2594	12
1	2594	14
1	2594	15
1	2594	16
1	2594	18
1	2594	20
1	2594	21
1	2594	22
1	2594	23
1	2594	24
1	2594	25
1	2595	2
1	2595	3
1	2595	4
1	2595	6
1	2595	9
1	2595	10
1	2595	12
1	2595	14
1	2595	16
1	2595	17
1	2595	18
1	2595	20
1	2595	22
1	2595	24
1	2595	25
1	2596	2
1	2596	5
1	2596	6
1	2596	9
1	2596	11
1	2596	12
1	2596	13
1	2596	14
1	2596	15
1	2596	16
1	2596	17
1	2596	19
1	2596	20
1	2596	24
1	2596	25
1	2597	4
1	2597	7
1	2597	8
1	2597	9
1	2597	11
1	2597	12
1	2597	13
1	2597	14
1	2597	15
1	2597	16
1	2597	17
1	2597	19
1	2597	21
1	2597	23
1	2597	25
1	2598	1
1	2598	3
1	2598	6
1	2598	9
1	2598	10
1	2598	11
1	2598	12
1	2598	13
1	2598	14
1	2598	17
1	2598	18
1	2598	19
1	2598	20
1	2598	23
1	2598	25
1	2599	1
1	2599	2
1	2599	3
1	2599	4
1	2599	6
1	2599	8
1	2599	9
1	2599	10
1	2599	11
1	2599	13
1	2599	17
1	2599	18
1	2599	19
1	2599	22
1	2599	23
1	2600	2
1	2600	5
1	2600	7
1	2600	9
1	2600	10
1	2600	11
1	2600	12
1	2600	14
1	2600	15
1	2600	16
1	2600	18
1	2600	22
1	2600	23
1	2600	24
1	2600	25
1	2601	1
1	2601	3
1	2601	4
1	2601	5
1	2601	6
1	2601	7
1	2601	13
1	2601	15
1	2601	16
1	2601	17
1	2601	20
1	2601	21
1	2601	22
1	2601	23
1	2601	24
1	2602	1
1	2602	2
1	2602	3
1	2602	4
1	2602	5
1	2602	6
1	2602	8
1	2602	10
1	2602	11
1	2602	12
1	2602	16
1	2602	18
1	2602	19
1	2602	20
1	2602	23
1	2603	2
1	2603	3
1	2603	5
1	2603	7
1	2603	9
1	2603	10
1	2603	11
1	2603	13
1	2603	15
1	2603	17
1	2603	19
1	2603	20
1	2603	21
1	2603	24
1	2603	25
1	2604	4
1	2604	5
1	2604	6
1	2604	7
1	2604	9
1	2604	12
1	2604	13
1	2604	14
1	2604	15
1	2604	16
1	2604	18
1	2604	19
1	2604	20
1	2604	22
1	2604	23
1	2605	1
1	2605	2
1	2605	5
1	2605	7
1	2605	9
1	2605	11
1	2605	12
1	2605	15
1	2605	16
1	2605	19
1	2605	21
1	2605	22
1	2605	23
1	2605	24
1	2605	25
1	2606	3
1	2606	6
1	2606	7
1	2606	8
1	2606	9
1	2606	10
1	2606	11
1	2606	14
1	2606	16
1	2606	18
1	2606	19
1	2606	20
1	2606	21
1	2606	23
1	2606	24
1	2607	1
1	2607	3
1	2607	5
1	2607	7
1	2607	8
1	2607	9
1	2607	10
1	2607	14
1	2607	16
1	2607	17
1	2607	18
1	2607	22
1	2607	23
1	2607	24
1	2607	25
1	2608	1
1	2608	2
1	2608	4
1	2608	8
1	2608	9
1	2608	11
1	2608	12
1	2608	14
1	2608	15
1	2608	17
1	2608	18
1	2608	19
1	2608	23
1	2608	24
1	2608	25
1	2609	3
1	2609	5
1	2609	6
1	2609	7
1	2609	9
1	2609	11
1	2609	12
1	2609	15
1	2609	17
1	2609	18
1	2609	19
1	2609	20
1	2609	21
1	2609	24
1	2609	25
1	2610	1
1	2610	3
1	2610	5
1	2610	7
1	2610	8
1	2610	9
1	2610	10
1	2610	11
1	2610	12
1	2610	15
1	2610	16
1	2610	17
1	2610	20
1	2610	22
1	2610	24
1	2611	2
1	2611	3
1	2611	4
1	2611	5
1	2611	6
1	2611	7
1	2611	8
1	2611	13
1	2611	14
1	2611	15
1	2611	17
1	2611	19
1	2611	21
1	2611	22
1	2611	25
1	2612	1
1	2612	3
1	2612	6
1	2612	9
1	2612	10
1	2612	11
1	2612	13
1	2612	16
1	2612	17
1	2612	18
1	2612	19
1	2612	20
1	2612	21
1	2612	23
1	2612	25
1	2613	1
1	2613	2
1	2613	3
1	2613	5
1	2613	6
1	2613	8
1	2613	11
1	2613	14
1	2613	15
1	2613	16
1	2613	18
1	2613	19
1	2613	20
1	2613	21
1	2613	25
1	2614	1
1	2614	2
1	2614	3
1	2614	4
1	2614	6
1	2614	10
1	2614	13
1	2614	16
1	2614	17
1	2614	19
1	2614	20
1	2614	21
1	2614	23
1	2614	24
1	2614	25
1	2615	2
1	2615	3
1	2615	5
1	2615	6
1	2615	8
1	2615	9
1	2615	10
1	2615	14
1	2615	15
1	2615	17
1	2615	19
1	2615	20
1	2615	21
1	2615	22
1	2615	25
1	2616	1
1	2616	2
1	2616	3
1	2616	4
1	2616	6
1	2616	7
1	2616	9
1	2616	10
1	2616	12
1	2616	14
1	2616	16
1	2616	18
1	2616	21
1	2616	22
1	2616	25
1	2617	1
1	2617	3
1	2617	5
1	2617	6
1	2617	7
1	2617	8
1	2617	10
1	2617	11
1	2617	12
1	2617	13
1	2617	17
1	2617	18
1	2617	22
1	2617	24
1	2617	25
1	2618	1
1	2618	2
1	2618	3
1	2618	4
1	2618	5
1	2618	6
1	2618	7
1	2618	9
1	2618	11
1	2618	16
1	2618	17
1	2618	18
1	2618	19
1	2618	20
1	2618	25
1	2619	3
1	2619	4
1	2619	5
1	2619	6
1	2619	7
1	2619	9
1	2619	10
1	2619	11
1	2619	12
1	2619	13
1	2619	15
1	2619	16
1	2619	17
1	2619	20
1	2619	25
1	2620	1
1	2620	2
1	2620	3
1	2620	5
1	2620	7
1	2620	9
1	2620	10
1	2620	11
1	2620	13
1	2620	14
1	2620	15
1	2620	16
1	2620	18
1	2620	19
1	2620	23
1	2621	2
1	2621	3
1	2621	4
1	2621	5
1	2621	7
1	2621	9
1	2621	10
1	2621	11
1	2621	12
1	2621	14
1	2621	15
1	2621	20
1	2621	22
1	2621	23
1	2621	25
1	2622	1
1	2622	2
1	2622	3
1	2622	4
1	2622	5
1	2622	6
1	2622	8
1	2622	9
1	2622	10
1	2622	12
1	2622	13
1	2622	17
1	2622	19
1	2622	20
1	2622	25
1	2623	1
1	2623	4
1	2623	5
1	2623	6
1	2623	7
1	2623	10
1	2623	11
1	2623	12
1	2623	13
1	2623	15
1	2623	16
1	2623	18
1	2623	22
1	2623	23
1	2623	24
1	2624	2
1	2624	4
1	2624	5
1	2624	7
1	2624	8
1	2624	12
1	2624	14
1	2624	17
1	2624	18
1	2624	20
1	2624	21
1	2624	22
1	2624	23
1	2624	24
1	2624	25
1	2625	3
1	2625	4
1	2625	5
1	2625	7
1	2625	8
1	2625	9
1	2625	10
1	2625	11
1	2625	12
1	2625	13
1	2625	18
1	2625	19
1	2625	20
1	2625	21
1	2625	25
1	2626	3
1	2626	4
1	2626	5
1	2626	6
1	2626	8
1	2626	10
1	2626	11
1	2626	12
1	2626	13
1	2626	14
1	2626	17
1	2626	20
1	2626	22
1	2626	23
1	2626	24
1	2627	1
1	2627	3
1	2627	7
1	2627	8
1	2627	9
1	2627	10
1	2627	13
1	2627	14
1	2627	16
1	2627	17
1	2627	20
1	2627	21
1	2627	22
1	2627	24
1	2627	25
1	2628	1
1	2628	4
1	2628	9
1	2628	10
1	2628	11
1	2628	12
1	2628	13
1	2628	14
1	2628	15
1	2628	17
1	2628	20
1	2628	21
1	2628	22
1	2628	23
1	2628	25
1	2629	2
1	2629	3
1	2629	4
1	2629	5
1	2629	6
1	2629	7
1	2629	9
1	2629	10
1	2629	12
1	2629	13
1	2629	14
1	2629	19
1	2629	21
1	2629	22
1	2629	25
1	2630	1
1	2630	2
1	2630	3
1	2630	6
1	2630	8
1	2630	9
1	2630	10
1	2630	13
1	2630	14
1	2630	16
1	2630	17
1	2630	20
1	2630	21
1	2630	22
1	2630	25
1	2631	2
1	2631	4
1	2631	5
1	2631	6
1	2631	7
1	2631	8
1	2631	11
1	2631	14
1	2631	17
1	2631	18
1	2631	19
1	2631	20
1	2631	21
1	2631	23
1	2631	24
1	2632	1
1	2632	4
1	2632	5
1	2632	7
1	2632	9
1	2632	11
1	2632	12
1	2632	13
1	2632	15
1	2632	16
1	2632	17
1	2632	19
1	2632	20
1	2632	21
1	2632	22
1	2633	1
1	2633	3
1	2633	4
1	2633	6
1	2633	9
1	2633	11
1	2633	12
1	2633	14
1	2633	15
1	2633	16
1	2633	17
1	2633	18
1	2633	19
1	2633	24
1	2633	25
1	2634	1
1	2634	2
1	2634	3
1	2634	4
1	2634	7
1	2634	9
1	2634	10
1	2634	14
1	2634	15
1	2634	16
1	2634	18
1	2634	20
1	2634	21
1	2634	22
1	2634	24
1	2635	2
1	2635	4
1	2635	5
1	2635	6
1	2635	8
1	2635	10
1	2635	11
1	2635	13
1	2635	14
1	2635	15
1	2635	17
1	2635	20
1	2635	21
1	2635	23
1	2635	25
1	2636	1
1	2636	3
1	2636	4
1	2636	5
1	2636	7
1	2636	8
1	2636	9
1	2636	10
1	2636	11
1	2636	13
1	2636	15
1	2636	18
1	2636	22
1	2636	24
1	2636	25
1	2637	2
1	2637	4
1	2637	5
1	2637	8
1	2637	9
1	2637	10
1	2637	12
1	2637	13
1	2637	19
1	2637	20
1	2637	21
1	2637	22
1	2637	23
1	2637	24
1	2637	25
1	2638	2
1	2638	4
1	2638	5
1	2638	9
1	2638	10
1	2638	12
1	2638	14
1	2638	15
1	2638	18
1	2638	19
1	2638	21
1	2638	22
1	2638	23
1	2638	24
1	2638	25
1	2639	2
1	2639	3
1	2639	7
1	2639	8
1	2639	9
1	2639	11
1	2639	12
1	2639	14
1	2639	15
1	2639	16
1	2639	18
1	2639	20
1	2639	21
1	2639	22
1	2639	24
1	2640	3
1	2640	6
1	2640	7
1	2640	9
1	2640	10
1	2640	11
1	2640	12
1	2640	14
1	2640	15
1	2640	16
1	2640	18
1	2640	19
1	2640	21
1	2640	22
1	2640	25
1	2641	1
1	2641	3
1	2641	4
1	2641	5
1	2641	7
1	2641	8
1	2641	9
1	2641	12
1	2641	13
1	2641	14
1	2641	17
1	2641	19
1	2641	20
1	2641	23
1	2641	24
1	2642	2
1	2642	4
1	2642	5
1	2642	8
1	2642	9
1	2642	13
1	2642	14
1	2642	15
1	2642	16
1	2642	17
1	2642	19
1	2642	20
1	2642	21
1	2642	22
1	2642	24
1	2643	1
1	2643	2
1	2643	3
1	2643	4
1	2643	6
1	2643	9
1	2643	11
1	2643	12
1	2643	13
1	2643	16
1	2643	18
1	2643	19
1	2643	20
1	2643	22
1	2643	25
1	2644	1
1	2644	2
1	2644	5
1	2644	6
1	2644	8
1	2644	10
1	2644	11
1	2644	12
1	2644	13
1	2644	15
1	2644	16
1	2644	17
1	2644	18
1	2644	19
1	2644	20
1	2645	1
1	2645	2
1	2645	3
1	2645	5
1	2645	6
1	2645	7
1	2645	11
1	2645	12
1	2645	13
1	2645	14
1	2645	15
1	2645	17
1	2645	18
1	2645	20
1	2645	24
1	2646	2
1	2646	3
1	2646	6
1	2646	8
1	2646	9
1	2646	10
1	2646	12
1	2646	13
1	2646	14
1	2646	15
1	2646	17
1	2646	20
1	2646	22
1	2646	23
1	2646	25
1	2647	1
1	2647	3
1	2647	4
1	2647	5
1	2647	6
1	2647	9
1	2647	10
1	2647	13
1	2647	16
1	2647	17
1	2647	18
1	2647	19
1	2647	22
1	2647	24
1	2647	25
1	2648	4
1	2648	7
1	2648	8
1	2648	10
1	2648	11
1	2648	12
1	2648	13
1	2648	14
1	2648	15
1	2648	16
1	2648	17
1	2648	18
1	2648	20
1	2648	22
1	2648	25
1	2649	2
1	2649	3
1	2649	6
1	2649	7
1	2649	8
1	2649	10
1	2649	12
1	2649	14
1	2649	15
1	2649	16
1	2649	17
1	2649	19
1	2649	20
1	2649	23
1	2649	24
1	2650	2
1	2650	4
1	2650	5
1	2650	6
1	2650	7
1	2650	9
1	2650	11
1	2650	12
1	2650	13
1	2650	14
1	2650	15
1	2650	18
1	2650	19
1	2650	20
1	2650	22
1	2651	3
1	2651	4
1	2651	10
1	2651	11
1	2651	12
1	2651	13
1	2651	15
1	2651	16
1	2651	17
1	2651	18
1	2651	19
1	2651	22
1	2651	23
1	2651	24
1	2651	25
1	2652	1
1	2652	3
1	2652	4
1	2652	5
1	2652	6
1	2652	8
1	2652	10
1	2652	12
1	2652	14
1	2652	15
1	2652	16
1	2652	17
1	2652	19
1	2652	24
1	2652	25
1	2653	2
1	2653	3
1	2653	7
1	2653	8
1	2653	9
1	2653	10
1	2653	12
1	2653	13
1	2653	14
1	2653	15
1	2653	17
1	2653	18
1	2653	19
1	2653	20
1	2653	21
1	2654	1
1	2654	3
1	2654	5
1	2654	6
1	2654	9
1	2654	10
1	2654	13
1	2654	15
1	2654	16
1	2654	17
1	2654	19
1	2654	20
1	2654	21
1	2654	24
1	2654	25
1	2655	1
1	2655	5
1	2655	6
1	2655	8
1	2655	9
1	2655	11
1	2655	13
1	2655	14
1	2655	15
1	2655	16
1	2655	19
1	2655	20
1	2655	21
1	2655	22
1	2655	23
1	2656	2
1	2656	3
1	2656	4
1	2656	7
1	2656	9
1	2656	10
1	2656	11
1	2656	12
1	2656	13
1	2656	17
1	2656	18
1	2656	19
1	2656	20
1	2656	21
1	2656	25
1	2657	1
1	2657	2
1	2657	3
1	2657	5
1	2657	6
1	2657	7
1	2657	8
1	2657	10
1	2657	12
1	2657	13
1	2657	15
1	2657	16
1	2657	17
1	2657	21
1	2657	24
1	2658	1
1	2658	2
1	2658	3
1	2658	4
1	2658	5
1	2658	8
1	2658	9
1	2658	10
1	2658	12
1	2658	14
1	2658	15
1	2658	16
1	2658	18
1	2658	21
1	2658	24
1	2659	1
1	2659	3
1	2659	5
1	2659	7
1	2659	10
1	2659	11
1	2659	13
1	2659	15
1	2659	18
1	2659	19
1	2659	20
1	2659	21
1	2659	22
1	2659	23
1	2659	24
1	2660	1
1	2660	2
1	2660	3
1	2660	6
1	2660	8
1	2660	10
1	2660	13
1	2660	14
1	2660	15
1	2660	16
1	2660	18
1	2660	19
1	2660	21
1	2660	24
1	2660	25
1	2661	1
1	2661	3
1	2661	4
1	2661	5
1	2661	6
1	2661	8
1	2661	9
1	2661	10
1	2661	12
1	2661	15
1	2661	16
1	2661	17
1	2661	18
1	2661	22
1	2661	25
1	2662	3
1	2662	4
1	2662	5
1	2662	6
1	2662	9
1	2662	10
1	2662	12
1	2662	13
1	2662	14
1	2662	16
1	2662	17
1	2662	19
1	2662	20
1	2662	22
1	2662	23
1	2663	1
1	2663	3
1	2663	5
1	2663	6
1	2663	7
1	2663	11
1	2663	12
1	2663	13
1	2663	14
1	2663	16
1	2663	18
1	2663	19
1	2663	21
1	2663	22
1	2663	25
1	2664	1
1	2664	4
1	2664	5
1	2664	6
1	2664	7
1	2664	8
1	2664	9
1	2664	10
1	2664	11
1	2664	12
1	2664	17
1	2664	18
1	2664	23
1	2664	24
1	2664	25
1	2665	3
1	2665	6
1	2665	7
1	2665	8
1	2665	9
1	2665	11
1	2665	12
1	2665	13
1	2665	15
1	2665	16
1	2665	18
1	2665	19
1	2665	20
1	2665	21
1	2665	25
1	2666	2
1	2666	3
1	2666	4
1	2666	7
1	2666	8
1	2666	10
1	2666	11
1	2666	12
1	2666	13
1	2666	19
1	2666	20
1	2666	21
1	2666	22
1	2666	23
1	2666	24
1	2667	1
1	2667	2
1	2667	3
1	2667	4
1	2667	8
1	2667	9
1	2667	10
1	2667	11
1	2667	13
1	2667	15
1	2667	19
1	2667	20
1	2667	23
1	2667	24
1	2667	25
1	2668	1
1	2668	3
1	2668	5
1	2668	8
1	2668	9
1	2668	13
1	2668	15
1	2668	16
1	2668	17
1	2668	18
1	2668	19
1	2668	20
1	2668	22
1	2668	23
1	2668	24
1	2669	1
1	2669	4
1	2669	6
1	2669	7
1	2669	8
1	2669	9
1	2669	10
1	2669	11
1	2669	14
1	2669	15
1	2669	19
1	2669	20
1	2669	21
1	2669	24
1	2669	25
1	2670	1
1	2670	3
1	2670	5
1	2670	7
1	2670	8
1	2670	13
1	2670	15
1	2670	17
1	2670	18
1	2670	19
1	2670	21
1	2670	22
1	2670	23
1	2670	24
1	2670	25
1	2671	1
1	2671	2
1	2671	5
1	2671	7
1	2671	8
1	2671	9
1	2671	10
1	2671	11
1	2671	12
1	2671	13
1	2671	18
1	2671	20
1	2671	21
1	2671	22
1	2671	25
1	2672	2
1	2672	3
1	2672	5
1	2672	6
1	2672	9
1	2672	10
1	2672	11
1	2672	13
1	2672	15
1	2672	16
1	2672	17
1	2672	19
1	2672	21
1	2672	22
1	2672	24
1	2673	2
1	2673	3
1	2673	4
1	2673	5
1	2673	7
1	2673	8
1	2673	10
1	2673	11
1	2673	12
1	2673	14
1	2673	15
1	2673	20
1	2673	22
1	2673	23
1	2673	24
1	2674	1
1	2674	2
1	2674	3
1	2674	4
1	2674	5
1	2674	7
1	2674	8
1	2674	11
1	2674	12
1	2674	13
1	2674	14
1	2674	15
1	2674	16
1	2674	20
1	2674	25
1	2675	2
1	2675	4
1	2675	7
1	2675	9
1	2675	10
1	2675	12
1	2675	13
1	2675	14
1	2675	16
1	2675	18
1	2675	20
1	2675	22
1	2675	23
1	2675	24
1	2675	25
1	2676	2
1	2676	6
1	2676	8
1	2676	9
1	2676	11
1	2676	13
1	2676	14
1	2676	15
1	2676	16
1	2676	18
1	2676	19
1	2676	21
1	2676	22
1	2676	23
1	2676	25
1	2677	1
1	2677	3
1	2677	4
1	2677	6
1	2677	8
1	2677	10
1	2677	11
1	2677	12
1	2677	14
1	2677	16
1	2677	17
1	2677	18
1	2677	21
1	2677	22
1	2677	24
1	2678	2
1	2678	4
1	2678	5
1	2678	6
1	2678	7
1	2678	8
1	2678	9
1	2678	10
1	2678	11
1	2678	15
1	2678	16
1	2678	17
1	2678	20
1	2678	22
1	2678	24
1	2679	4
1	2679	5
1	2679	6
1	2679	7
1	2679	8
1	2679	9
1	2679	10
1	2679	12
1	2679	13
1	2679	16
1	2679	19
1	2679	20
1	2679	22
1	2679	24
1	2679	25
1	2680	1
1	2680	2
1	2680	4
1	2680	5
1	2680	9
1	2680	10
1	2680	11
1	2680	13
1	2680	15
1	2680	16
1	2680	17
1	2680	19
1	2680	20
1	2680	23
1	2680	24
1	2681	2
1	2681	4
1	2681	7
1	2681	8
1	2681	10
1	2681	12
1	2681	13
1	2681	14
1	2681	16
1	2681	17
1	2681	18
1	2681	19
1	2681	21
1	2681	22
1	2681	24
1	2682	3
1	2682	4
1	2682	6
1	2682	7
1	2682	8
1	2682	9
1	2682	10
1	2682	11
1	2682	12
1	2682	14
1	2682	15
1	2682	16
1	2682	19
1	2682	23
1	2682	24
1	2683	1
1	2683	2
1	2683	3
1	2683	4
1	2683	8
1	2683	10
1	2683	11
1	2683	12
1	2683	13
1	2683	14
1	2683	20
1	2683	21
1	2683	22
1	2683	23
1	2683	25
1	2684	2
1	2684	4
1	2684	6
1	2684	7
1	2684	8
1	2684	9
1	2684	10
1	2684	11
1	2684	12
1	2684	13
1	2684	15
1	2684	20
1	2684	22
1	2684	23
1	2684	25
1	2685	4
1	2685	5
1	2685	6
1	2685	7
1	2685	8
1	2685	9
1	2685	11
1	2685	16
1	2685	17
1	2685	18
1	2685	20
1	2685	21
1	2685	22
1	2685	24
1	2685	25
1	2686	1
1	2686	3
1	2686	4
1	2686	5
1	2686	7
1	2686	8
1	2686	9
1	2686	13
1	2686	14
1	2686	15
1	2686	16
1	2686	19
1	2686	20
1	2686	21
1	2686	24
1	2687	3
1	2687	4
1	2687	5
1	2687	6
1	2687	7
1	2687	10
1	2687	11
1	2687	13
1	2687	14
1	2687	15
1	2687	16
1	2687	19
1	2687	20
1	2687	21
1	2687	22
1	2688	2
1	2688	4
1	2688	5
1	2688	6
1	2688	7
1	2688	8
1	2688	10
1	2688	11
1	2688	14
1	2688	16
1	2688	17
1	2688	18
1	2688	20
1	2688	22
1	2688	25
1	2689	2
1	2689	3
1	2689	4
1	2689	5
1	2689	8
1	2689	9
1	2689	10
1	2689	14
1	2689	15
1	2689	16
1	2689	18
1	2689	21
1	2689	22
1	2689	23
1	2689	24
1	2690	1
1	2690	3
1	2690	5
1	2690	6
1	2690	7
1	2690	8
1	2690	11
1	2690	12
1	2690	15
1	2690	17
1	2690	18
1	2690	20
1	2690	21
1	2690	23
1	2690	24
1	2691	1
1	2691	2
1	2691	6
1	2691	9
1	2691	10
1	2691	11
1	2691	12
1	2691	13
1	2691	15
1	2691	17
1	2691	18
1	2691	19
1	2691	21
1	2691	24
1	2691	25
1	2692	1
1	2692	2
1	2692	3
1	2692	4
1	2692	6
1	2692	8
1	2692	9
1	2692	11
1	2692	13
1	2692	14
1	2692	15
1	2692	20
1	2692	21
1	2692	22
1	2692	24
1	2693	3
1	2693	7
1	2693	8
1	2693	9
1	2693	10
1	2693	13
1	2693	14
1	2693	15
1	2693	16
1	2693	19
1	2693	20
1	2693	21
1	2693	22
1	2693	24
1	2693	25
1	2694	3
1	2694	5
1	2694	7
1	2694	8
1	2694	9
1	2694	10
1	2694	11
1	2694	12
1	2694	13
1	2694	14
1	2694	15
1	2694	20
1	2694	21
1	2694	23
1	2694	24
1	2695	1
1	2695	2
1	2695	8
1	2695	9
1	2695	10
1	2695	11
1	2695	12
1	2695	13
1	2695	15
1	2695	17
1	2695	20
1	2695	21
1	2695	23
1	2695	24
1	2695	25
1	2696	1
1	2696	2
1	2696	3
1	2696	4
1	2696	6
1	2696	7
1	2696	8
1	2696	9
1	2696	11
1	2696	13
1	2696	14
1	2696	15
1	2696	16
1	2696	18
1	2696	22
1	2697	2
1	2697	5
1	2697	6
1	2697	9
1	2697	10
1	2697	11
1	2697	13
1	2697	14
1	2697	15
1	2697	18
1	2697	19
1	2697	20
1	2697	21
1	2697	22
1	2697	25
1	2698	1
1	2698	2
1	2698	3
1	2698	4
1	2698	5
1	2698	8
1	2698	9
1	2698	10
1	2698	12
1	2698	17
1	2698	20
1	2698	22
1	2698	23
1	2698	24
1	2698	25
1	2699	1
1	2699	3
1	2699	4
1	2699	6
1	2699	7
1	2699	8
1	2699	11
1	2699	13
1	2699	14
1	2699	15
1	2699	16
1	2699	20
1	2699	22
1	2699	23
1	2699	24
1	2700	3
1	2700	4
1	2700	5
1	2700	6
1	2700	7
1	2700	9
1	2700	13
1	2700	14
1	2700	16
1	2700	17
1	2700	19
1	2700	21
1	2700	22
1	2700	24
1	2700	25
1	2701	1
1	2701	3
1	2701	4
1	2701	5
1	2701	7
1	2701	9
1	2701	12
1	2701	14
1	2701	16
1	2701	18
1	2701	19
1	2701	21
1	2701	22
1	2701	23
1	2701	25
1	2702	1
1	2702	2
1	2702	4
1	2702	6
1	2702	7
1	2702	10
1	2702	14
1	2702	15
1	2702	16
1	2702	17
1	2702	18
1	2702	19
1	2702	21
1	2702	23
1	2702	25
1	2703	1
1	2703	2
1	2703	5
1	2703	7
1	2703	9
1	2703	10
1	2703	12
1	2703	13
1	2703	14
1	2703	17
1	2703	19
1	2703	20
1	2703	21
1	2703	23
1	2703	24
1	2704	2
1	2704	5
1	2704	7
1	2704	8
1	2704	9
1	2704	10
1	2704	11
1	2704	12
1	2704	13
1	2704	16
1	2704	18
1	2704	19
1	2704	20
1	2704	21
1	2704	23
1	2705	2
1	2705	3
1	2705	4
1	2705	7
1	2705	8
1	2705	9
1	2705	14
1	2705	16
1	2705	17
1	2705	18
1	2705	19
1	2705	20
1	2705	22
1	2705	24
1	2705	25
1	2706	1
1	2706	3
1	2706	4
1	2706	7
1	2706	8
1	2706	9
1	2706	10
1	2706	11
1	2706	12
1	2706	13
1	2706	15
1	2706	18
1	2706	21
1	2706	22
1	2706	25
1	2707	1
1	2707	2
1	2707	4
1	2707	5
1	2707	8
1	2707	9
1	2707	10
1	2707	11
1	2707	14
1	2707	15
1	2707	16
1	2707	17
1	2707	18
1	2707	21
1	2707	25
1	2708	1
1	2708	2
1	2708	3
1	2708	5
1	2708	6
1	2708	13
1	2708	14
1	2708	16
1	2708	18
1	2708	19
1	2708	21
1	2708	22
1	2708	23
1	2708	24
1	2708	25
1	2709	1
1	2709	2
1	2709	3
1	2709	5
1	2709	9
1	2709	10
1	2709	11
1	2709	12
1	2709	13
1	2709	19
1	2709	21
1	2709	22
1	2709	23
1	2709	24
1	2709	25
1	2710	1
1	2710	2
1	2710	3
1	2710	4
1	2710	7
1	2710	10
1	2710	11
1	2710	12
1	2710	13
1	2710	14
1	2710	16
1	2710	17
1	2710	20
1	2710	24
1	2710	25
1	2711	1
1	2711	3
1	2711	4
1	2711	8
1	2711	11
1	2711	12
1	2711	15
1	2711	16
1	2711	18
1	2711	19
1	2711	20
1	2711	22
1	2711	23
1	2711	24
1	2711	25
1	2712	2
1	2712	3
1	2712	8
1	2712	11
1	2712	12
1	2712	13
1	2712	16
1	2712	17
1	2712	18
1	2712	19
1	2712	20
1	2712	22
1	2712	23
1	2712	24
1	2712	25
1	2713	2
1	2713	3
1	2713	5
1	2713	6
1	2713	7
1	2713	8
1	2713	9
1	2713	12
1	2713	15
1	2713	18
1	2713	19
1	2713	20
1	2713	21
1	2713	22
1	2713	24
1	2714	2
1	2714	3
1	2714	5
1	2714	6
1	2714	8
1	2714	9
1	2714	11
1	2714	13
1	2714	16
1	2714	17
1	2714	18
1	2714	21
1	2714	23
1	2714	24
1	2714	25
1	2715	2
1	2715	4
1	2715	6
1	2715	7
1	2715	11
1	2715	12
1	2715	13
1	2715	14
1	2715	15
1	2715	17
1	2715	18
1	2715	19
1	2715	22
1	2715	23
1	2715	25
1	2716	1
1	2716	4
1	2716	6
1	2716	8
1	2716	9
1	2716	10
1	2716	13
1	2716	14
1	2716	15
1	2716	17
1	2716	18
1	2716	19
1	2716	20
1	2716	21
1	2716	24
1	2717	2
1	2717	3
1	2717	4
1	2717	5
1	2717	9
1	2717	10
1	2717	11
1	2717	14
1	2717	15
1	2717	16
1	2717	17
1	2717	20
1	2717	21
1	2717	22
1	2717	24
1	2718	1
1	2718	2
1	2718	3
1	2718	4
1	2718	6
1	2718	7
1	2718	8
1	2718	12
1	2718	15
1	2718	19
1	2718	20
1	2718	21
1	2718	22
1	2718	23
1	2718	25
1	2719	1
1	2719	4
1	2719	5
1	2719	6
1	2719	8
1	2719	10
1	2719	11
1	2719	13
1	2719	14
1	2719	15
1	2719	17
1	2719	19
1	2719	22
1	2719	23
1	2719	24
1	2720	1
1	2720	4
1	2720	5
1	2720	6
1	2720	7
1	2720	8
1	2720	9
1	2720	11
1	2720	13
1	2720	15
1	2720	17
1	2720	19
1	2720	21
1	2720	22
1	2720	23
1	2721	1
1	2721	3
1	2721	5
1	2721	8
1	2721	10
1	2721	11
1	2721	12
1	2721	13
1	2721	14
1	2721	16
1	2721	18
1	2721	19
1	2721	20
1	2721	21
1	2721	25
1	2722	1
1	2722	2
1	2722	3
1	2722	4
1	2722	5
1	2722	6
1	2722	8
1	2722	12
1	2722	18
1	2722	20
1	2722	21
1	2722	22
1	2722	23
1	2722	24
1	2722	25
1	2723	1
1	2723	2
1	2723	3
1	2723	6
1	2723	7
1	2723	8
1	2723	10
1	2723	12
1	2723	15
1	2723	17
1	2723	20
1	2723	21
1	2723	22
1	2723	23
1	2723	24
1	2724	1
1	2724	3
1	2724	5
1	2724	6
1	2724	8
1	2724	12
1	2724	13
1	2724	14
1	2724	17
1	2724	19
1	2724	20
1	2724	21
1	2724	22
1	2724	24
1	2724	25
1	2725	1
1	2725	2
1	2725	4
1	2725	5
1	2725	7
1	2725	8
1	2725	9
1	2725	10
1	2725	11
1	2725	12
1	2725	14
1	2725	17
1	2725	22
1	2725	23
1	2725	24
1	2726	2
1	2726	5
1	2726	6
1	2726	8
1	2726	9
1	2726	10
1	2726	11
1	2726	14
1	2726	16
1	2726	17
1	2726	18
1	2726	19
1	2726	20
1	2726	21
1	2726	23
1	2727	2
1	2727	3
1	2727	4
1	2727	8
1	2727	9
1	2727	10
1	2727	11
1	2727	12
1	2727	13
1	2727	16
1	2727	17
1	2727	18
1	2727	19
1	2727	20
1	2727	23
1	2728	1
1	2728	2
1	2728	3
1	2728	4
1	2728	5
1	2728	9
1	2728	10
1	2728	11
1	2728	13
1	2728	14
1	2728	16
1	2728	17
1	2728	18
1	2728	20
1	2728	22
1	2729	2
1	2729	4
1	2729	5
1	2729	6
1	2729	8
1	2729	9
1	2729	10
1	2729	12
1	2729	13
1	2729	14
1	2729	19
1	2729	20
1	2729	21
1	2729	22
1	2729	25
1	2730	2
1	2730	4
1	2730	7
1	2730	10
1	2730	11
1	2730	13
1	2730	14
1	2730	15
1	2730	16
1	2730	19
1	2730	20
1	2730	21
1	2730	23
1	2730	24
1	2730	25
1	2731	1
1	2731	3
1	2731	7
1	2731	8
1	2731	9
1	2731	11
1	2731	12
1	2731	13
1	2731	14
1	2731	18
1	2731	19
1	2731	20
1	2731	21
1	2731	23
1	2731	25
1	2732	2
1	2732	3
1	2732	5
1	2732	6
1	2732	8
1	2732	10
1	2732	12
1	2732	15
1	2732	16
1	2732	18
1	2732	19
1	2732	20
1	2732	21
1	2732	24
1	2732	25
1	2733	1
1	2733	3
1	2733	4
1	2733	6
1	2733	7
1	2733	8
1	2733	10
1	2733	11
1	2733	12
1	2733	14
1	2733	19
1	2733	21
1	2733	22
1	2733	24
1	2733	25
1	2734	1
1	2734	3
1	2734	5
1	2734	6
1	2734	8
1	2734	10
1	2734	11
1	2734	12
1	2734	14
1	2734	15
1	2734	17
1	2734	18
1	2734	21
1	2734	22
1	2734	23
1	2735	1
1	2735	2
1	2735	4
1	2735	5
1	2735	6
1	2735	8
1	2735	9
1	2735	11
1	2735	12
1	2735	14
1	2735	17
1	2735	18
1	2735	21
1	2735	23
1	2735	24
1	2736	1
1	2736	3
1	2736	6
1	2736	8
1	2736	11
1	2736	12
1	2736	14
1	2736	15
1	2736	17
1	2736	18
1	2736	19
1	2736	20
1	2736	21
1	2736	23
1	2736	25
1	2737	3
1	2737	4
1	2737	5
1	2737	7
1	2737	9
1	2737	10
1	2737	11
1	2737	16
1	2737	17
1	2737	18
1	2737	19
1	2737	20
1	2737	23
1	2737	24
1	2737	25
1	2738	1
1	2738	3
1	2738	4
1	2738	10
1	2738	11
1	2738	12
1	2738	13
1	2738	14
1	2738	15
1	2738	16
1	2738	19
1	2738	20
1	2738	21
1	2738	24
1	2738	25
1	2739	1
1	2739	2
1	2739	3
1	2739	4
1	2739	5
1	2739	6
1	2739	7
1	2739	11
1	2739	13
1	2739	15
1	2739	16
1	2739	18
1	2739	22
1	2739	23
1	2739	25
1	2740	2
1	2740	3
1	2740	5
1	2740	6
1	2740	7
1	2740	8
1	2740	9
1	2740	10
1	2740	11
1	2740	13
1	2740	14
1	2740	15
1	2740	17
1	2740	19
1	2740	23
1	2741	1
1	2741	2
1	2741	4
1	2741	5
1	2741	6
1	2741	7
1	2741	8
1	2741	9
1	2741	13
1	2741	15
1	2741	18
1	2741	22
1	2741	23
1	2741	24
1	2741	25
1	2742	1
1	2742	2
1	2742	4
1	2742	5
1	2742	7
1	2742	9
1	2742	11
1	2742	12
1	2742	13
1	2742	14
1	2742	15
1	2742	17
1	2742	18
1	2742	20
1	2742	22
1	2743	1
1	2743	4
1	2743	6
1	2743	8
1	2743	9
1	2743	12
1	2743	13
1	2743	16
1	2743	17
1	2743	18
1	2743	19
1	2743	20
1	2743	22
1	2743	23
1	2743	24
1	2744	1
1	2744	2
1	2744	3
1	2744	4
1	2744	6
1	2744	7
1	2744	8
1	2744	9
1	2744	11
1	2744	12
1	2744	15
1	2744	20
1	2744	21
1	2744	23
1	2744	25
1	2745	1
1	2745	6
1	2745	7
1	2745	9
1	2745	10
1	2745	11
1	2745	12
1	2745	14
1	2745	15
1	2745	17
1	2745	19
1	2745	22
1	2745	23
1	2745	24
1	2745	25
1	2746	1
1	2746	3
1	2746	4
1	2746	6
1	2746	7
1	2746	10
1	2746	11
1	2746	12
1	2746	13
1	2746	17
1	2746	18
1	2746	19
1	2746	23
1	2746	24
1	2746	25
1	2747	1
1	2747	2
1	2747	5
1	2747	7
1	2747	8
1	2747	10
1	2747	11
1	2747	12
1	2747	14
1	2747	17
1	2747	18
1	2747	19
1	2747	20
1	2747	21
1	2747	25
1	2748	1
1	2748	2
1	2748	4
1	2748	5
1	2748	6
1	2748	8
1	2748	9
1	2748	10
1	2748	12
1	2748	14
1	2748	16
1	2748	19
1	2748	22
1	2748	23
1	2748	24
1	2749	2
1	2749	5
1	2749	6
1	2749	7
1	2749	9
1	2749	10
1	2749	12
1	2749	13
1	2749	14
1	2749	16
1	2749	18
1	2749	20
1	2749	21
1	2749	22
1	2749	24
1	2750	1
1	2750	2
1	2750	6
1	2750	7
1	2750	8
1	2750	9
1	2750	11
1	2750	13
1	2750	14
1	2750	16
1	2750	17
1	2750	18
1	2750	21
1	2750	22
1	2750	23
1	2751	1
1	2751	2
1	2751	3
1	2751	5
1	2751	9
1	2751	10
1	2751	12
1	2751	13
1	2751	15
1	2751	16
1	2751	17
1	2751	19
1	2751	23
1	2751	24
1	2751	25
1	2752	2
1	2752	3
1	2752	4
1	2752	7
1	2752	10
1	2752	11
1	2752	12
1	2752	15
1	2752	16
1	2752	17
1	2752	20
1	2752	21
1	2752	22
1	2752	23
1	2752	25
1	2753	2
1	2753	5
1	2753	7
1	2753	8
1	2753	11
1	2753	12
1	2753	14
1	2753	16
1	2753	17
1	2753	18
1	2753	20
1	2753	21
1	2753	22
1	2753	24
1	2753	25
1	2754	2
1	2754	3
1	2754	4
1	2754	8
1	2754	9
1	2754	10
1	2754	13
1	2754	14
1	2754	16
1	2754	17
1	2754	18
1	2754	19
1	2754	20
1	2754	24
1	2754	25
1	2755	1
1	2755	3
1	2755	5
1	2755	7
1	2755	8
1	2755	9
1	2755	10
1	2755	11
1	2755	12
1	2755	15
1	2755	16
1	2755	17
1	2755	21
1	2755	22
1	2755	23
1	2756	1
1	2756	2
1	2756	5
1	2756	6
1	2756	8
1	2756	10
1	2756	11
1	2756	12
1	2756	14
1	2756	15
1	2756	18
1	2756	20
1	2756	21
1	2756	22
1	2756	23
1	2757	1
1	2757	3
1	2757	5
1	2757	6
1	2757	7
1	2757	8
1	2757	9
1	2757	10
1	2757	12
1	2757	13
1	2757	17
1	2757	18
1	2757	19
1	2757	23
1	2757	25
1	2758	1
1	2758	2
1	2758	3
1	2758	4
1	2758	7
1	2758	10
1	2758	11
1	2758	12
1	2758	13
1	2758	16
1	2758	18
1	2758	21
1	2758	22
1	2758	23
1	2758	24
1	2759	2
1	2759	3
1	2759	7
1	2759	9
1	2759	10
1	2759	11
1	2759	12
1	2759	13
1	2759	15
1	2759	17
1	2759	18
1	2759	19
1	2759	20
1	2759	21
1	2759	23
1	2760	1
1	2760	2
1	2760	4
1	2760	6
1	2760	7
1	2760	10
1	2760	11
1	2760	13
1	2760	14
1	2760	15
1	2760	17
1	2760	18
1	2760	20
1	2760	22
1	2760	24
1	2761	1
1	2761	2
1	2761	3
1	2761	4
1	2761	8
1	2761	11
1	2761	13
1	2761	14
1	2761	15
1	2761	17
1	2761	18
1	2761	19
1	2761	20
1	2761	21
1	2761	22
1	2762	2
1	2762	5
1	2762	6
1	2762	9
1	2762	10
1	2762	11
1	2762	12
1	2762	13
1	2762	16
1	2762	17
1	2762	19
1	2762	21
1	2762	22
1	2762	23
1	2762	24
1	2763	1
1	2763	2
1	2763	4
1	2763	6
1	2763	8
1	2763	9
1	2763	10
1	2763	11
1	2763	13
1	2763	15
1	2763	16
1	2763	18
1	2763	19
1	2763	20
1	2763	23
1	2764	1
1	2764	2
1	2764	4
1	2764	5
1	2764	7
1	2764	10
1	2764	11
1	2764	12
1	2764	13
1	2764	16
1	2764	19
1	2764	20
1	2764	23
1	2764	24
1	2764	25
1	2765	2
1	2765	3
1	2765	5
1	2765	6
1	2765	7
1	2765	11
1	2765	14
1	2765	15
1	2765	16
1	2765	19
1	2765	20
1	2765	21
1	2765	23
1	2765	24
1	2765	25
1	2766	1
1	2766	3
1	2766	4
1	2766	6
1	2766	8
1	2766	9
1	2766	11
1	2766	14
1	2766	15
1	2766	17
1	2766	19
1	2766	21
1	2766	22
1	2766	23
1	2766	25
1	2767	2
1	2767	3
1	2767	6
1	2767	7
1	2767	8
1	2767	11
1	2767	15
1	2767	16
1	2767	17
1	2767	18
1	2767	19
1	2767	20
1	2767	21
1	2767	22
1	2767	24
1	2768	1
1	2768	4
1	2768	5
1	2768	7
1	2768	9
1	2768	11
1	2768	13
1	2768	14
1	2768	15
1	2768	16
1	2768	19
1	2768	20
1	2768	22
1	2768	23
1	2768	25
1	2769	1
1	2769	2
1	2769	3
1	2769	5
1	2769	7
1	2769	8
1	2769	10
1	2769	11
1	2769	12
1	2769	16
1	2769	17
1	2769	18
1	2769	21
1	2769	24
1	2769	25
1	2770	2
1	2770	3
1	2770	4
1	2770	6
1	2770	8
1	2770	10
1	2770	11
1	2770	12
1	2770	13
1	2770	15
1	2770	18
1	2770	19
1	2770	20
1	2770	21
1	2770	23
1	2771	4
1	2771	6
1	2771	7
1	2771	8
1	2771	9
1	2771	12
1	2771	15
1	2771	16
1	2771	17
1	2771	18
1	2771	19
1	2771	20
1	2771	22
1	2771	23
1	2771	25
1	2772	1
1	2772	2
1	2772	5
1	2772	7
1	2772	8
1	2772	9
1	2772	10
1	2772	11
1	2772	12
1	2772	16
1	2772	17
1	2772	19
1	2772	23
1	2772	24
1	2772	25
1	2773	1
1	2773	2
1	2773	3
1	2773	4
1	2773	5
1	2773	7
1	2773	11
1	2773	14
1	2773	16
1	2773	18
1	2773	20
1	2773	21
1	2773	22
1	2773	23
1	2773	24
1	2774	1
1	2774	2
1	2774	4
1	2774	6
1	2774	8
1	2774	12
1	2774	13
1	2774	15
1	2774	18
1	2774	20
1	2774	21
1	2774	22
1	2774	23
1	2774	24
1	2774	25
1	2775	1
1	2775	2
1	2775	3
1	2775	4
1	2775	8
1	2775	12
1	2775	14
1	2775	15
1	2775	18
1	2775	19
1	2775	20
1	2775	22
1	2775	23
1	2775	24
1	2775	25
1	2776	1
1	2776	2
1	2776	4
1	2776	5
1	2776	8
1	2776	12
1	2776	13
1	2776	14
1	2776	15
1	2776	17
1	2776	18
1	2776	19
1	2776	20
1	2776	22
1	2776	23
1	2777	3
1	2777	6
1	2777	7
1	2777	8
1	2777	9
1	2777	11
1	2777	12
1	2777	13
1	2777	14
1	2777	15
1	2777	17
1	2777	20
1	2777	21
1	2777	24
1	2777	25
1	2778	1
1	2778	4
1	2778	5
1	2778	6
1	2778	9
1	2778	10
1	2778	11
1	2778	12
1	2778	13
1	2778	15
1	2778	18
1	2778	19
1	2778	20
1	2778	22
1	2778	25
1	2779	1
1	2779	2
1	2779	6
1	2779	7
1	2779	8
1	2779	9
1	2779	10
1	2779	11
1	2779	12
1	2779	15
1	2779	18
1	2779	20
1	2779	21
1	2779	23
1	2779	25
1	2780	3
1	2780	4
1	2780	7
1	2780	9
1	2780	10
1	2780	11
1	2780	13
1	2780	14
1	2780	17
1	2780	19
1	2780	20
1	2780	21
1	2780	22
1	2780	23
1	2780	24
1	2781	3
1	2781	4
1	2781	5
1	2781	7
1	2781	8
1	2781	10
1	2781	14
1	2781	15
1	2781	16
1	2781	17
1	2781	18
1	2781	20
1	2781	23
1	2781	24
1	2781	25
1	2782	1
1	2782	4
1	2782	6
1	2782	9
1	2782	10
1	2782	11
1	2782	12
1	2782	16
1	2782	17
1	2782	18
1	2782	19
1	2782	20
1	2782	22
1	2782	23
1	2782	24
1	2783	2
1	2783	4
1	2783	7
1	2783	8
1	2783	9
1	2783	10
1	2783	11
1	2783	13
1	2783	15
1	2783	19
1	2783	20
1	2783	21
1	2783	22
1	2783	24
1	2783	25
1	2784	1
1	2784	2
1	2784	3
1	2784	4
1	2784	6
1	2784	7
1	2784	8
1	2784	10
1	2784	11
1	2784	14
1	2784	15
1	2784	19
1	2784	21
1	2784	22
1	2784	25
1	2785	1
1	2785	4
1	2785	5
1	2785	9
1	2785	11
1	2785	14
1	2785	15
1	2785	17
1	2785	18
1	2785	19
1	2785	20
1	2785	21
1	2785	23
1	2785	24
1	2785	25
1	2786	1
1	2786	2
1	2786	3
1	2786	5
1	2786	6
1	2786	7
1	2786	10
1	2786	12
1	2786	15
1	2786	16
1	2786	17
1	2786	18
1	2786	21
1	2786	23
1	2786	25
1	2787	1
1	2787	4
1	2787	7
1	2787	9
1	2787	11
1	2787	12
1	2787	14
1	2787	16
1	2787	18
1	2787	19
1	2787	21
1	2787	22
1	2787	23
1	2787	24
1	2787	25
1	2788	2
1	2788	3
1	2788	5
1	2788	6
1	2788	7
1	2788	8
1	2788	9
1	2788	10
1	2788	12
1	2788	14
1	2788	15
1	2788	19
1	2788	20
1	2788	24
1	2788	25
1	2789	3
1	2789	4
1	2789	6
1	2789	7
1	2789	8
1	2789	9
1	2789	10
1	2789	12
1	2789	13
1	2789	14
1	2789	15
1	2789	18
1	2789	19
1	2789	20
1	2789	25
1	2790	2
1	2790	3
1	2790	5
1	2790	7
1	2790	8
1	2790	9
1	2790	10
1	2790	11
1	2790	12
1	2790	13
1	2790	16
1	2790	20
1	2790	21
1	2790	22
1	2790	25
1	2791	3
1	2791	4
1	2791	6
1	2791	8
1	2791	10
1	2791	11
1	2791	14
1	2791	15
1	2791	16
1	2791	17
1	2791	20
1	2791	22
1	2791	23
1	2791	24
1	2791	25
1	2792	1
1	2792	3
1	2792	6
1	2792	8
1	2792	9
1	2792	10
1	2792	11
1	2792	13
1	2792	16
1	2792	17
1	2792	18
1	2792	20
1	2792	21
1	2792	23
1	2792	25
1	2793	2
1	2793	3
1	2793	4
1	2793	5
1	2793	6
1	2793	7
1	2793	8
1	2793	13
1	2793	14
1	2793	15
1	2793	18
1	2793	20
1	2793	21
1	2793	22
1	2793	24
1	2794	1
1	2794	2
1	2794	3
1	2794	5
1	2794	6
1	2794	8
1	2794	10
1	2794	14
1	2794	15
1	2794	16
1	2794	17
1	2794	20
1	2794	21
1	2794	22
1	2794	25
1	2795	1
1	2795	2
1	2795	3
1	2795	4
1	2795	5
1	2795	6
1	2795	7
1	2795	8
1	2795	9
1	2795	11
1	2795	15
1	2795	18
1	2795	19
1	2795	22
1	2795	25
1	2796	1
1	2796	3
1	2796	4
1	2796	7
1	2796	9
1	2796	10
1	2796	12
1	2796	15
1	2796	16
1	2796	19
1	2796	20
1	2796	21
1	2796	22
1	2796	24
1	2796	25
1	2797	3
1	2797	4
1	2797	5
1	2797	6
1	2797	10
1	2797	11
1	2797	13
1	2797	14
1	2797	16
1	2797	18
1	2797	19
1	2797	20
1	2797	22
1	2797	23
1	2797	25
1	2798	1
1	2798	2
1	2798	3
1	2798	5
1	2798	7
1	2798	8
1	2798	12
1	2798	14
1	2798	15
1	2798	16
1	2798	18
1	2798	20
1	2798	22
1	2798	23
1	2798	24
1	2799	1
1	2799	3
1	2799	6
1	2799	9
1	2799	10
1	2799	11
1	2799	13
1	2799	14
1	2799	15
1	2799	16
1	2799	18
1	2799	20
1	2799	21
1	2799	22
1	2799	23
1	2800	2
1	2800	3
1	2800	5
1	2800	6
1	2800	7
1	2800	9
1	2800	13
1	2800	14
1	2800	15
1	2800	16
1	2800	17
1	2800	20
1	2800	21
1	2800	22
1	2800	23
1	2801	1
1	2801	2
1	2801	3
1	2801	7
1	2801	9
1	2801	12
1	2801	15
1	2801	16
1	2801	17
1	2801	18
1	2801	19
1	2801	20
1	2801	22
1	2801	24
1	2801	25
1	2802	1
1	2802	2
1	2802	3
1	2802	4
1	2802	6
1	2802	8
1	2802	9
1	2802	12
1	2802	13
1	2802	16
1	2802	17
1	2802	18
1	2802	22
1	2802	23
1	2802	25
1	2803	1
1	2803	5
1	2803	6
1	2803	7
1	2803	8
1	2803	9
1	2803	12
1	2803	13
1	2803	14
1	2803	16
1	2803	18
1	2803	20
1	2803	21
1	2803	24
1	2803	25
1	2804	2
1	2804	3
1	2804	4
1	2804	7
1	2804	8
1	2804	9
1	2804	10
1	2804	11
1	2804	12
1	2804	13
1	2804	14
1	2804	16
1	2804	21
1	2804	23
1	2804	24
1	2805	5
1	2805	6
1	2805	7
1	2805	8
1	2805	10
1	2805	11
1	2805	12
1	2805	13
1	2805	14
1	2805	18
1	2805	19
1	2805	20
1	2805	22
1	2805	23
1	2805	25
1	2806	1
1	2806	2
1	2806	3
1	2806	4
1	2806	5
1	2806	11
1	2806	12
1	2806	13
1	2806	14
1	2806	16
1	2806	17
1	2806	19
1	2806	20
1	2806	23
1	2806	25
1	2807	1
1	2807	3
1	2807	5
1	2807	6
1	2807	7
1	2807	9
1	2807	10
1	2807	11
1	2807	12
1	2807	13
1	2807	14
1	2807	15
1	2807	16
1	2807	22
1	2807	24
1	2808	4
1	2808	6
1	2808	8
1	2808	9
1	2808	10
1	2808	12
1	2808	13
1	2808	14
1	2808	15
1	2808	18
1	2808	19
1	2808	20
1	2808	21
1	2808	22
1	2808	24
1	2809	1
1	2809	2
1	2809	4
1	2809	5
1	2809	7
1	2809	8
1	2809	13
1	2809	15
1	2809	18
1	2809	19
1	2809	20
1	2809	21
1	2809	22
1	2809	24
1	2809	25
1	2810	2
1	2810	4
1	2810	5
1	2810	7
1	2810	10
1	2810	11
1	2810	12
1	2810	13
1	2810	14
1	2810	18
1	2810	19
1	2810	20
1	2810	23
1	2810	24
1	2810	25
1	2811	2
1	2811	3
1	2811	4
1	2811	5
1	2811	6
1	2811	7
1	2811	8
1	2811	9
1	2811	10
1	2811	11
1	2811	15
1	2811	16
1	2811	22
1	2811	23
1	2811	25
1	2812	1
1	2812	3
1	2812	8
1	2812	11
1	2812	12
1	2812	13
1	2812	14
1	2812	15
1	2812	19
1	2812	20
1	2812	21
1	2812	22
1	2812	23
1	2812	24
1	2812	25
1	2813	1
1	2813	2
1	2813	3
1	2813	4
1	2813	7
1	2813	11
1	2813	13
1	2813	14
1	2813	15
1	2813	18
1	2813	19
1	2813	21
1	2813	22
1	2813	24
1	2813	25
1	2814	1
1	2814	2
1	2814	4
1	2814	7
1	2814	8
1	2814	11
1	2814	12
1	2814	13
1	2814	15
1	2814	19
1	2814	20
1	2814	22
1	2814	23
1	2814	24
1	2814	25
1	2815	3
1	2815	4
1	2815	5
1	2815	6
1	2815	7
1	2815	8
1	2815	9
1	2815	10
1	2815	13
1	2815	16
1	2815	18
1	2815	19
1	2815	22
1	2815	24
1	2815	25
1	2816	1
1	2816	2
1	2816	8
1	2816	9
1	2816	11
1	2816	13
1	2816	14
1	2816	15
1	2816	16
1	2816	18
1	2816	19
1	2816	21
1	2816	22
1	2816	24
1	2816	25
1	2817	3
1	2817	4
1	2817	5
1	2817	7
1	2817	8
1	2817	12
1	2817	13
1	2817	17
1	2817	18
1	2817	19
1	2817	20
1	2817	21
1	2817	22
1	2817	24
1	2817	25
1	2818	1
1	2818	2
1	2818	3
1	2818	4
1	2818	5
1	2818	7
1	2818	9
1	2818	10
1	2818	11
1	2818	12
1	2818	13
1	2818	14
1	2818	15
1	2818	17
1	2818	24
1	2819	1
1	2819	2
1	2819	4
1	2819	5
1	2819	6
1	2819	8
1	2819	10
1	2819	11
1	2819	14
1	2819	18
1	2819	20
1	2819	21
1	2819	22
1	2819	23
1	2819	24
1	2820	4
1	2820	5
1	2820	6
1	2820	9
1	2820	10
1	2820	12
1	2820	13
1	2820	14
1	2820	17
1	2820	18
1	2820	19
1	2820	20
1	2820	21
1	2820	23
1	2820	25
1	2821	2
1	2821	3
1	2821	4
1	2821	5
1	2821	6
1	2821	8
1	2821	9
1	2821	10
1	2821	12
1	2821	13
1	2821	19
1	2821	20
1	2821	21
1	2821	22
1	2821	23
1	2822	1
1	2822	3
1	2822	4
1	2822	5
1	2822	6
1	2822	9
1	2822	10
1	2822	11
1	2822	12
1	2822	17
1	2822	20
1	2822	21
1	2822	23
1	2822	24
1	2822	25
1	2823	1
1	2823	4
1	2823	6
1	2823	13
1	2823	14
1	2823	15
1	2823	16
1	2823	17
1	2823	18
1	2823	19
1	2823	20
1	2823	21
1	2823	23
1	2823	24
1	2823	25
1	2824	1
1	2824	2
1	2824	5
1	2824	7
1	2824	9
1	2824	12
1	2824	13
1	2824	14
1	2824	15
1	2824	16
1	2824	20
1	2824	21
1	2824	22
1	2824	24
1	2824	25
1	2825	2
1	2825	3
1	2825	4
1	2825	6
1	2825	7
1	2825	8
1	2825	9
1	2825	14
1	2825	17
1	2825	18
1	2825	20
1	2825	21
1	2825	22
1	2825	24
1	2825	25
1	2826	1
1	2826	2
1	2826	3
1	2826	5
1	2826	7
1	2826	9
1	2826	11
1	2826	12
1	2826	13
1	2826	16
1	2826	17
1	2826	18
1	2826	19
1	2826	21
1	2826	23
1	2827	1
1	2827	2
1	2827	3
1	2827	5
1	2827	6
1	2827	7
1	2827	10
1	2827	13
1	2827	15
1	2827	16
1	2827	17
1	2827	18
1	2827	19
1	2827	21
1	2827	24
1	2828	1
1	2828	5
1	2828	6
1	2828	8
1	2828	11
1	2828	12
1	2828	14
1	2828	15
1	2828	16
1	2828	17
1	2828	18
1	2828	19
1	2828	20
1	2828	21
1	2828	25
1	2829	2
1	2829	3
1	2829	5
1	2829	6
1	2829	7
1	2829	8
1	2829	9
1	2829	10
1	2829	11
1	2829	13
1	2829	14
1	2829	15
1	2829	17
1	2829	18
1	2829	25
1	2830	2
1	2830	3
1	2830	4
1	2830	8
1	2830	9
1	2830	10
1	2830	11
1	2830	12
1	2830	13
1	2830	17
1	2830	18
1	2830	20
1	2830	21
1	2830	22
1	2830	25
1	2831	2
1	2831	3
1	2831	5
1	2831	7
1	2831	10
1	2831	11
1	2831	13
1	2831	14
1	2831	15
1	2831	16
1	2831	17
1	2831	19
1	2831	20
1	2831	22
1	2831	25
1	2832	1
1	2832	2
1	2832	3
1	2832	5
1	2832	6
1	2832	11
1	2832	14
1	2832	15
1	2832	16
1	2832	19
1	2832	20
1	2832	21
1	2832	22
1	2832	23
1	2832	24
1	2833	2
1	2833	3
1	2833	4
1	2833	5
1	2833	6
1	2833	11
1	2833	13
1	2833	14
1	2833	16
1	2833	18
1	2833	19
1	2833	22
1	2833	23
1	2833	24
1	2833	25
1	2834	1
1	2834	6
1	2834	8
1	2834	10
1	2834	11
1	2834	12
1	2834	13
1	2834	14
1	2834	17
1	2834	19
1	2834	20
1	2834	21
1	2834	22
1	2834	23
1	2834	25
1	2835	2
1	2835	4
1	2835	6
1	2835	7
1	2835	8
1	2835	9
1	2835	10
1	2835	12
1	2835	13
1	2835	14
1	2835	15
1	2835	16
1	2835	21
1	2835	22
1	2835	25
1	2836	1
1	2836	2
1	2836	3
1	2836	4
1	2836	7
1	2836	9
1	2836	12
1	2836	14
1	2836	15
1	2836	17
1	2836	18
1	2836	20
1	2836	21
1	2836	22
1	2836	23
1	2837	1
1	2837	2
1	2837	5
1	2837	6
1	2837	8
1	2837	10
1	2837	12
1	2837	17
1	2837	18
1	2837	19
1	2837	20
1	2837	21
1	2837	22
1	2837	24
1	2837	25
1	2838	3
1	2838	4
1	2838	5
1	2838	6
1	2838	7
1	2838	8
1	2838	10
1	2838	11
1	2838	12
1	2838	13
1	2838	15
1	2838	16
1	2838	21
1	2838	23
1	2838	25
1	2839	1
1	2839	3
1	2839	4
1	2839	5
1	2839	6
1	2839	10
1	2839	12
1	2839	13
1	2839	15
1	2839	16
1	2839	17
1	2839	18
1	2839	20
1	2839	21
1	2839	24
1	2840	1
1	2840	2
1	2840	4
1	2840	5
1	2840	6
1	2840	7
1	2840	10
1	2840	11
1	2840	13
1	2840	14
1	2840	16
1	2840	20
1	2840	22
1	2840	24
1	2840	25
1	2841	3
1	2841	5
1	2841	6
1	2841	7
1	2841	8
1	2841	9
1	2841	14
1	2841	17
1	2841	18
1	2841	19
1	2841	20
1	2841	21
1	2841	23
1	2841	24
1	2841	25
1	2842	3
1	2842	6
1	2842	7
1	2842	8
1	2842	10
1	2842	11
1	2842	12
1	2842	13
1	2842	17
1	2842	18
1	2842	20
1	2842	21
1	2842	22
1	2842	24
1	2842	25
1	2843	2
1	2843	4
1	2843	7
1	2843	9
1	2843	10
1	2843	12
1	2843	13
1	2843	16
1	2843	18
1	2843	20
1	2843	21
1	2843	22
1	2843	23
1	2843	24
1	2843	25
1	2844	4
1	2844	5
1	2844	6
1	2844	7
1	2844	10
1	2844	11
1	2844	12
1	2844	13
1	2844	14
1	2844	17
1	2844	21
1	2844	22
1	2844	23
1	2844	24
1	2844	25
1	2845	1
1	2845	2
1	2845	5
1	2845	7
1	2845	8
1	2845	10
1	2845	11
1	2845	12
1	2845	15
1	2845	17
1	2845	18
1	2845	19
1	2845	20
1	2845	23
1	2845	24
1	2846	4
1	2846	6
1	2846	8
1	2846	9
1	2846	10
1	2846	12
1	2846	13
1	2846	14
1	2846	15
1	2846	17
1	2846	19
1	2846	20
1	2846	21
1	2846	23
1	2846	24
1	2847	2
1	2847	4
1	2847	5
1	2847	6
1	2847	8
1	2847	9
1	2847	10
1	2847	12
1	2847	13
1	2847	14
1	2847	15
1	2847	18
1	2847	21
1	2847	22
1	2847	24
1	2848	1
1	2848	2
1	2848	4
1	2848	6
1	2848	7
1	2848	9
1	2848	11
1	2848	12
1	2848	13
1	2848	16
1	2848	17
1	2848	19
1	2848	23
1	2848	24
1	2848	25
1	2849	1
1	2849	2
1	2849	6
1	2849	9
1	2849	10
1	2849	11
1	2849	12
1	2849	15
1	2849	16
1	2849	18
1	2849	19
1	2849	20
1	2849	21
1	2849	24
1	2849	25
1	2850	1
1	2850	2
1	2850	6
1	2850	9
1	2850	11
1	2850	12
1	2850	14
1	2850	15
1	2850	16
1	2850	18
1	2850	19
1	2850	20
1	2850	22
1	2850	23
1	2850	24
1	2851	1
1	2851	3
1	2851	5
1	2851	6
1	2851	8
1	2851	9
1	2851	10
1	2851	12
1	2851	15
1	2851	16
1	2851	19
1	2851	20
1	2851	21
1	2851	22
1	2851	25
1	2852	1
1	2852	2
1	2852	4
1	2852	6
1	2852	8
1	2852	9
1	2852	10
1	2852	12
1	2852	13
1	2852	14
1	2852	15
1	2852	17
1	2852	19
1	2852	22
1	2852	24
1	2853	1
1	2853	2
1	2853	3
1	2853	4
1	2853	5
1	2853	9
1	2853	11
1	2853	12
1	2853	13
1	2853	14
1	2853	17
1	2853	21
1	2853	22
1	2853	24
1	2853	25
1	2854	1
1	2854	3
1	2854	5
1	2854	7
1	2854	8
1	2854	9
1	2854	10
1	2854	12
1	2854	14
1	2854	15
1	2854	17
1	2854	19
1	2854	20
1	2854	23
1	2854	25
1	2855	1
1	2855	2
1	2855	3
1	2855	4
1	2855	7
1	2855	8
1	2855	9
1	2855	10
1	2855	16
1	2855	17
1	2855	19
1	2855	21
1	2855	22
1	2855	23
1	2855	24
1	2856	1
1	2856	2
1	2856	3
1	2856	4
1	2856	5
1	2856	7
1	2856	9
1	2856	12
1	2856	15
1	2856	18
1	2856	20
1	2856	22
1	2856	23
1	2856	24
1	2856	25
1	2857	1
1	2857	3
1	2857	4
1	2857	6
1	2857	7
1	2857	8
1	2857	9
1	2857	10
1	2857	12
1	2857	15
1	2857	16
1	2857	17
1	2857	19
1	2857	22
1	2857	23
1	2858	1
1	2858	2
1	2858	4
1	2858	5
1	2858	6
1	2858	8
1	2858	11
1	2858	12
1	2858	13
1	2858	15
1	2858	17
1	2858	19
1	2858	20
1	2858	22
1	2858	24
1	2859	1
1	2859	2
1	2859	5
1	2859	6
1	2859	8
1	2859	9
1	2859	10
1	2859	11
1	2859	12
1	2859	14
1	2859	17
1	2859	18
1	2859	21
1	2859	22
1	2859	25
1	2860	1
1	2860	2
1	2860	3
1	2860	4
1	2860	5
1	2860	8
1	2860	9
1	2860	12
1	2860	13
1	2860	14
1	2860	15
1	2860	16
1	2860	18
1	2860	20
1	2860	21
1	2861	1
1	2861	5
1	2861	7
1	2861	10
1	2861	11
1	2861	12
1	2861	14
1	2861	15
1	2861	16
1	2861	17
1	2861	18
1	2861	19
1	2861	20
1	2861	21
1	2861	25
1	2862	1
1	2862	2
1	2862	3
1	2862	4
1	2862	6
1	2862	8
1	2862	9
1	2862	12
1	2862	13
1	2862	16
1	2862	18
1	2862	20
1	2862	21
1	2862	22
1	2862	23
1	2863	1
1	2863	2
1	2863	5
1	2863	6
1	2863	7
1	2863	8
1	2863	9
1	2863	11
1	2863	13
1	2863	14
1	2863	19
1	2863	20
1	2863	21
1	2863	22
1	2863	25
1	2864	3
1	2864	4
1	2864	5
1	2864	6
1	2864	7
1	2864	8
1	2864	9
1	2864	10
1	2864	11
1	2864	15
1	2864	16
1	2864	17
1	2864	19
1	2864	22
1	2864	23
1	2865	2
1	2865	4
1	2865	5
1	2865	6
1	2865	9
1	2865	11
1	2865	12
1	2865	13
1	2865	14
1	2865	15
1	2865	18
1	2865	20
1	2865	21
1	2865	22
1	2865	23
1	2866	1
1	2866	2
1	2866	3
1	2866	7
1	2866	8
1	2866	9
1	2866	11
1	2866	12
1	2866	14
1	2866	16
1	2866	17
1	2866	21
1	2866	22
1	2866	24
1	2866	25
1	2867	1
1	2867	5
1	2867	7
1	2867	9
1	2867	10
1	2867	12
1	2867	13
1	2867	14
1	2867	15
1	2867	18
1	2867	20
1	2867	21
1	2867	22
1	2867	23
1	2867	25
1	2868	1
1	2868	2
1	2868	3
1	2868	4
1	2868	6
1	2868	7
1	2868	8
1	2868	9
1	2868	10
1	2868	14
1	2868	17
1	2868	22
1	2868	23
1	2868	24
1	2868	25
1	2869	1
1	2869	2
1	2869	3
1	2869	4
1	2869	6
1	2869	7
1	2869	9
1	2869	10
1	2869	11
1	2869	13
1	2869	16
1	2869	19
1	2869	23
1	2869	24
1	2869	25
1	2870	1
1	2870	2
1	2870	4
1	2870	5
1	2870	7
1	2870	9
1	2870	10
1	2870	11
1	2870	14
1	2870	15
1	2870	16
1	2870	17
1	2870	19
1	2870	22
1	2870	25
1	2871	1
1	2871	2
1	2871	5
1	2871	6
1	2871	7
1	2871	8
1	2871	9
1	2871	10
1	2871	12
1	2871	16
1	2871	17
1	2871	20
1	2871	21
1	2871	23
1	2871	25
1	2872	1
1	2872	2
1	2872	6
1	2872	7
1	2872	9
1	2872	12
1	2872	13
1	2872	14
1	2872	17
1	2872	18
1	2872	19
1	2872	21
1	2872	22
1	2872	23
1	2872	25
1	2873	1
1	2873	6
1	2873	7
1	2873	8
1	2873	10
1	2873	12
1	2873	14
1	2873	15
1	2873	16
1	2873	18
1	2873	21
1	2873	22
1	2873	23
1	2873	24
1	2873	25
1	2874	1
1	2874	3
1	2874	4
1	2874	6
1	2874	7
1	2874	9
1	2874	10
1	2874	11
1	2874	12
1	2874	13
1	2874	17
1	2874	18
1	2874	19
1	2874	20
1	2874	23
1	2875	1
1	2875	2
1	2875	4
1	2875	6
1	2875	7
1	2875	8
1	2875	9
1	2875	11
1	2875	12
1	2875	13
1	2875	14
1	2875	15
1	2875	18
1	2875	19
1	2875	25
1	2876	2
1	2876	3
1	2876	5
1	2876	6
1	2876	7
1	2876	8
1	2876	9
1	2876	10
1	2876	14
1	2876	15
1	2876	16
1	2876	18
1	2876	20
1	2876	22
1	2876	25
1	2877	1
1	2877	3
1	2877	7
1	2877	9
1	2877	10
1	2877	12
1	2877	13
1	2877	14
1	2877	15
1	2877	17
1	2877	19
1	2877	20
1	2877	22
1	2877	24
1	2877	25
1	2878	1
1	2878	2
1	2878	4
1	2878	5
1	2878	7
1	2878	11
1	2878	12
1	2878	13
1	2878	14
1	2878	15
1	2878	18
1	2878	20
1	2878	21
1	2878	22
1	2878	24
1	2879	1
1	2879	2
1	2879	3
1	2879	4
1	2879	6
1	2879	7
1	2879	10
1	2879	12
1	2879	13
1	2879	16
1	2879	17
1	2879	19
1	2879	20
1	2879	24
1	2879	25
1	2880	1
1	2880	2
1	2880	4
1	2880	5
1	2880	7
1	2880	8
1	2880	9
1	2880	12
1	2880	13
1	2880	14
1	2880	15
1	2880	21
1	2880	22
1	2880	23
1	2880	25
1	2881	1
1	2881	3
1	2881	4
1	2881	6
1	2881	7
1	2881	10
1	2881	11
1	2881	12
1	2881	13
1	2881	16
1	2881	18
1	2881	19
1	2881	20
1	2881	23
1	2881	25
1	2882	2
1	2882	3
1	2882	6
1	2882	7
1	2882	9
1	2882	10
1	2882	14
1	2882	16
1	2882	17
1	2882	19
1	2882	20
1	2882	21
1	2882	22
1	2882	23
1	2882	24
1	2883	5
1	2883	7
1	2883	8
1	2883	9
1	2883	10
1	2883	11
1	2883	12
1	2883	13
1	2883	15
1	2883	17
1	2883	18
1	2883	19
1	2883	20
1	2883	21
1	2883	25
1	2884	1
1	2884	2
1	2884	3
1	2884	6
1	2884	7
1	2884	10
1	2884	11
1	2884	12
1	2884	14
1	2884	16
1	2884	18
1	2884	20
1	2884	21
1	2884	22
1	2884	23
1	2885	2
1	2885	3
1	2885	7
1	2885	8
1	2885	10
1	2885	11
1	2885	14
1	2885	16
1	2885	17
1	2885	18
1	2885	19
1	2885	21
1	2885	22
1	2885	23
1	2885	24
1	2886	1
1	2886	4
1	2886	5
1	2886	7
1	2886	8
1	2886	9
1	2886	13
1	2886	14
1	2886	15
1	2886	16
1	2886	17
1	2886	19
1	2886	22
1	2886	24
1	2886	25
1	2887	1
1	2887	2
1	2887	3
1	2887	7
1	2887	9
1	2887	10
1	2887	11
1	2887	12
1	2887	17
1	2887	18
1	2887	19
1	2887	20
1	2887	21
1	2887	22
1	2887	24
1	2888	1
1	2888	2
1	2888	4
1	2888	7
1	2888	8
1	2888	10
1	2888	12
1	2888	13
1	2888	15
1	2888	17
1	2888	19
1	2888	20
1	2888	22
1	2888	24
1	2888	25
1	2889	2
1	2889	4
1	2889	6
1	2889	7
1	2889	8
1	2889	10
1	2889	12
1	2889	14
1	2889	15
1	2889	16
1	2889	18
1	2889	20
1	2889	23
1	2889	24
1	2889	25
1	2890	1
1	2890	4
1	2890	6
1	2890	7
1	2890	9
1	2890	10
1	2890	11
1	2890	12
1	2890	15
1	2890	16
1	2890	18
1	2890	19
1	2890	20
1	2890	21
1	2890	23
1	2891	1
1	2891	2
1	2891	5
1	2891	6
1	2891	10
1	2891	11
1	2891	12
1	2891	13
1	2891	15
1	2891	17
1	2891	18
1	2891	20
1	2891	21
1	2891	23
1	2891	24
1	2892	4
1	2892	5
1	2892	6
1	2892	8
1	2892	9
1	2892	10
1	2892	14
1	2892	16
1	2892	17
1	2892	18
1	2892	19
1	2892	20
1	2892	21
1	2892	22
1	2892	23
1	2893	1
1	2893	4
1	2893	5
1	2893	6
1	2893	8
1	2893	9
1	2893	10
1	2893	11
1	2893	17
1	2893	19
1	2893	20
1	2893	21
1	2893	23
1	2893	24
1	2893	25
1	2894	1
1	2894	2
1	2894	3
1	2894	4
1	2894	5
1	2894	6
1	2894	7
1	2894	8
1	2894	13
1	2894	14
1	2894	15
1	2894	17
1	2894	20
1	2894	22
1	2894	23
1	2895	2
1	2895	3
1	2895	5
1	2895	8
1	2895	9
1	2895	11
1	2895	14
1	2895	15
1	2895	16
1	2895	17
1	2895	18
1	2895	21
1	2895	22
1	2895	24
1	2895	25
1	2896	1
1	2896	2
1	2896	5
1	2896	7
1	2896	8
1	2896	9
1	2896	11
1	2896	13
1	2896	15
1	2896	16
1	2896	17
1	2896	18
1	2896	20
1	2896	23
1	2896	24
1	2897	1
1	2897	7
1	2897	9
1	2897	10
1	2897	11
1	2897	12
1	2897	13
1	2897	14
1	2897	17
1	2897	18
1	2897	19
1	2897	21
1	2897	23
1	2897	24
1	2897	25
1	2898	1
1	2898	6
1	2898	9
1	2898	10
1	2898	12
1	2898	14
1	2898	15
1	2898	16
1	2898	17
1	2898	18
1	2898	20
1	2898	21
1	2898	22
1	2898	23
1	2898	24
1	2899	2
1	2899	3
1	2899	5
1	2899	7
1	2899	8
1	2899	10
1	2899	13
1	2899	14
1	2899	15
1	2899	16
1	2899	17
1	2899	18
1	2899	19
1	2899	22
1	2899	25
1	2900	1
1	2900	3
1	2900	4
1	2900	5
1	2900	6
1	2900	7
1	2900	10
1	2900	11
1	2900	14
1	2900	18
1	2900	19
1	2900	20
1	2900	23
1	2900	24
1	2900	25
1	2901	1
1	2901	4
1	2901	5
1	2901	9
1	2901	10
1	2901	13
1	2901	14
1	2901	15
1	2901	16
1	2901	17
1	2901	20
1	2901	21
1	2901	22
1	2901	23
1	2901	25
1	2902	2
1	2902	3
1	2902	4
1	2902	5
1	2902	6
1	2902	7
1	2902	8
1	2902	10
1	2902	11
1	2902	13
1	2902	15
1	2902	19
1	2902	21
1	2902	24
1	2902	25
1	2903	2
1	2903	3
1	2903	4
1	2903	5
1	2903	10
1	2903	12
1	2903	14
1	2903	16
1	2903	17
1	2903	18
1	2903	20
1	2903	21
1	2903	23
1	2903	24
1	2903	25
1	2904	1
1	2904	2
1	2904	4
1	2904	5
1	2904	8
1	2904	9
1	2904	10
1	2904	11
1	2904	14
1	2904	17
1	2904	18
1	2904	20
1	2904	21
1	2904	22
1	2904	24
1	2905	1
1	2905	2
1	2905	3
1	2905	4
1	2905	6
1	2905	9
1	2905	10
1	2905	11
1	2905	13
1	2905	14
1	2905	16
1	2905	20
1	2905	22
1	2905	23
1	2905	24
1	2906	1
1	2906	2
1	2906	3
1	2906	5
1	2906	6
1	2906	7
1	2906	9
1	2906	13
1	2906	15
1	2906	16
1	2906	17
1	2906	18
1	2906	19
1	2906	20
1	2906	23
1	2907	1
1	2907	2
1	2907	3
1	2907	7
1	2907	8
1	2907	9
1	2907	10
1	2907	13
1	2907	14
1	2907	15
1	2907	16
1	2907	17
1	2907	20
1	2907	22
1	2907	23
1	2908	5
1	2908	6
1	2908	7
1	2908	10
1	2908	11
1	2908	12
1	2908	13
1	2908	14
1	2908	16
1	2908	17
1	2908	18
1	2908	19
1	2908	20
1	2908	22
1	2908	24
1	2909	2
1	2909	5
1	2909	6
1	2909	7
1	2909	9
1	2909	10
1	2909	12
1	2909	16
1	2909	17
1	2909	18
1	2909	19
1	2909	20
1	2909	21
1	2909	23
1	2909	24
1	2910	1
1	2910	2
1	2910	6
1	2910	7
1	2910	8
1	2910	9
1	2910	10
1	2910	13
1	2910	15
1	2910	18
1	2910	19
1	2910	20
1	2910	21
1	2910	23
1	2910	24
1	2911	3
1	2911	4
1	2911	6
1	2911	8
1	2911	9
1	2911	10
1	2911	11
1	2911	16
1	2911	18
1	2911	19
1	2911	20
1	2911	22
1	2911	23
1	2911	24
1	2911	25
1	2912	1
1	2912	2
1	2912	4
1	2912	6
1	2912	10
1	2912	11
1	2912	14
1	2912	15
1	2912	16
1	2912	17
1	2912	19
1	2912	20
1	2912	22
1	2912	23
1	2912	25
1	2913	3
1	2913	4
1	2913	6
1	2913	7
1	2913	8
1	2913	9
1	2913	10
1	2913	12
1	2913	15
1	2913	17
1	2913	19
1	2913	21
1	2913	22
1	2913	24
1	2913	25
1	2914	3
1	2914	4
1	2914	5
1	2914	6
1	2914	7
1	2914	8
1	2914	9
1	2914	10
1	2914	11
1	2914	16
1	2914	17
1	2914	18
1	2914	20
1	2914	21
1	2914	25
1	2915	2
1	2915	4
1	2915	6
1	2915	7
1	2915	9
1	2915	11
1	2915	12
1	2915	13
1	2915	14
1	2915	15
1	2915	16
1	2915	19
1	2915	21
1	2915	23
1	2915	25
1	2916	1
1	2916	3
1	2916	5
1	2916	11
1	2916	12
1	2916	14
1	2916	15
1	2916	17
1	2916	18
1	2916	19
1	2916	20
1	2916	21
1	2916	22
1	2916	24
1	2916	25
1	2917	3
1	2917	4
1	2917	6
1	2917	9
1	2917	10
1	2917	14
1	2917	15
1	2917	16
1	2917	17
1	2917	19
1	2917	20
1	2917	21
1	2917	23
1	2917	24
1	2917	25
1	2918	2
1	2918	6
1	2918	7
1	2918	8
1	2918	10
1	2918	11
1	2918	12
1	2918	14
1	2918	15
1	2918	16
1	2918	18
1	2918	20
1	2918	23
1	2918	24
1	2918	25
1	2919	3
1	2919	4
1	2919	5
1	2919	6
1	2919	7
1	2919	9
1	2919	10
1	2919	13
1	2919	16
1	2919	17
1	2919	18
1	2919	20
1	2919	22
1	2919	24
1	2919	25
1	2920	1
1	2920	2
1	2920	4
1	2920	5
1	2920	6
1	2920	7
1	2920	9
1	2920	10
1	2920	12
1	2920	13
1	2920	14
1	2920	17
1	2920	18
1	2920	21
1	2920	22
1	2921	1
1	2921	3
1	2921	4
1	2921	7
1	2921	9
1	2921	13
1	2921	14
1	2921	15
1	2921	16
1	2921	17
1	2921	18
1	2921	19
1	2921	21
1	2921	22
1	2921	24
1	2922	1
1	2922	2
1	2922	4
1	2922	5
1	2922	6
1	2922	8
1	2922	11
1	2922	12
1	2922	13
1	2922	15
1	2922	16
1	2922	17
1	2922	19
1	2922	21
1	2922	24
1	2923	4
1	2923	6
1	2923	7
1	2923	9
1	2923	11
1	2923	12
1	2923	13
1	2923	16
1	2923	17
1	2923	18
1	2923	20
1	2923	22
1	2923	23
1	2923	24
1	2923	25
1	2924	2
1	2924	3
1	2924	4
1	2924	5
1	2924	6
1	2924	7
1	2924	8
1	2924	9
1	2924	12
1	2924	13
1	2924	14
1	2924	18
1	2924	20
1	2924	23
1	2924	24
1	2925	3
1	2925	4
1	2925	5
1	2925	6
1	2925	7
1	2925	8
1	2925	9
1	2925	10
1	2925	11
1	2925	18
1	2925	21
1	2925	22
1	2925	23
1	2925	24
1	2925	25
1	2926	1
1	2926	2
1	2926	3
1	2926	4
1	2926	7
1	2926	8
1	2926	9
1	2926	13
1	2926	15
1	2926	17
1	2926	18
1	2926	19
1	2926	22
1	2926	24
1	2926	25
1	2927	1
1	2927	4
1	2927	7
1	2927	8
1	2927	9
1	2927	11
1	2927	12
1	2927	14
1	2927	15
1	2927	16
1	2927	17
1	2927	21
1	2927	22
1	2927	23
1	2927	24
1	2928	1
1	2928	3
1	2928	4
1	2928	6
1	2928	7
1	2928	9
1	2928	13
1	2928	14
1	2928	15
1	2928	16
1	2928	17
1	2928	18
1	2928	19
1	2928	21
1	2928	24
1	2929	1
1	2929	2
1	2929	4
1	2929	6
1	2929	7
1	2929	9
1	2929	11
1	2929	12
1	2929	15
1	2929	17
1	2929	18
1	2929	20
1	2929	21
1	2929	24
1	2929	25
1	2930	1
1	2930	2
1	2930	3
1	2930	4
1	2930	6
1	2930	7
1	2930	9
1	2930	10
1	2930	11
1	2930	14
1	2930	16
1	2930	19
1	2930	21
1	2930	22
1	2930	23
1	2931	1
1	2931	2
1	2931	4
1	2931	5
1	2931	6
1	2931	7
1	2931	11
1	2931	13
1	2931	14
1	2931	16
1	2931	17
1	2931	18
1	2931	19
1	2931	20
1	2931	21
1	2932	2
1	2932	5
1	2932	6
1	2932	7
1	2932	8
1	2932	9
1	2932	10
1	2932	11
1	2932	14
1	2932	16
1	2932	17
1	2932	18
1	2932	20
1	2932	21
1	2932	24
1	2933	1
1	2933	2
1	2933	3
1	2933	4
1	2933	6
1	2933	7
1	2933	8
1	2933	10
1	2933	14
1	2933	15
1	2933	17
1	2933	18
1	2933	20
1	2933	22
1	2933	25
1	2934	2
1	2934	3
1	2934	6
1	2934	7
1	2934	8
1	2934	10
1	2934	11
1	2934	12
1	2934	13
1	2934	16
1	2934	18
1	2934	19
1	2934	20
1	2934	23
1	2934	24
1	2935	1
1	2935	3
1	2935	4
1	2935	6
1	2935	8
1	2935	9
1	2935	13
1	2935	14
1	2935	15
1	2935	19
1	2935	20
1	2935	21
1	2935	22
1	2935	24
1	2935	25
1	2936	1
1	2936	4
1	2936	8
1	2936	9
1	2936	10
1	2936	11
1	2936	12
1	2936	13
1	2936	16
1	2936	18
1	2936	19
1	2936	20
1	2936	21
1	2936	23
1	2936	24
1	2937	1
1	2937	2
1	2937	3
1	2937	4
1	2937	5
1	2937	6
1	2937	8
1	2937	9
1	2937	10
1	2937	13
1	2937	17
1	2937	21
1	2937	23
1	2937	24
1	2937	25
1	2938	1
1	2938	2
1	2938	3
1	2938	4
1	2938	5
1	2938	6
1	2938	8
1	2938	9
1	2938	10
1	2938	11
1	2938	15
1	2938	17
1	2938	20
1	2938	21
1	2938	24
1	2939	2
1	2939	3
1	2939	5
1	2939	6
1	2939	7
1	2939	9
1	2939	10
1	2939	11
1	2939	12
1	2939	13
1	2939	17
1	2939	18
1	2939	20
1	2939	22
1	2939	23
1	2940	1
1	2940	2
1	2940	5
1	2940	7
1	2940	8
1	2940	9
1	2940	11
1	2940	12
1	2940	13
1	2940	14
1	2940	15
1	2940	20
1	2940	21
1	2940	24
1	2940	25
1	2941	4
1	2941	5
1	2941	6
1	2941	7
1	2941	8
1	2941	10
1	2941	11
1	2941	12
1	2941	14
1	2941	17
1	2941	20
1	2941	21
1	2941	22
1	2941	24
1	2941	25
1	2942	4
1	2942	5
1	2942	6
1	2942	7
1	2942	8
1	2942	9
1	2942	10
1	2942	14
1	2942	16
1	2942	17
1	2942	18
1	2942	19
1	2942	20
1	2942	23
1	2942	25
1	2943	1
1	2943	4
1	2943	5
1	2943	8
1	2943	9
1	2943	10
1	2943	11
1	2943	12
1	2943	15
1	2943	16
1	2943	17
1	2943	18
1	2943	19
1	2943	20
1	2943	25
1	2944	1
1	2944	2
1	2944	4
1	2944	5
1	2944	6
1	2944	7
1	2944	11
1	2944	12
1	2944	13
1	2944	15
1	2944	17
1	2944	18
1	2944	20
1	2944	21
1	2944	24
1	2945	5
1	2945	6
1	2945	7
1	2945	8
1	2945	10
1	2945	13
1	2945	14
1	2945	15
1	2945	17
1	2945	18
1	2945	19
1	2945	20
1	2945	21
1	2945	22
1	2945	25
1	2946	1
1	2946	3
1	2946	4
1	2946	5
1	2946	10
1	2946	12
1	2946	13
1	2946	14
1	2946	15
1	2946	16
1	2946	19
1	2946	20
1	2946	23
1	2946	24
1	2946	25
1	2947	2
1	2947	3
1	2947	4
1	2947	6
1	2947	7
1	2947	8
1	2947	9
1	2947	11
1	2947	12
1	2947	13
1	2947	15
1	2947	20
1	2947	22
1	2947	24
1	2947	25
1	2948	1
1	2948	3
1	2948	5
1	2948	7
1	2948	8
1	2948	9
1	2948	10
1	2948	11
1	2948	12
1	2948	16
1	2948	18
1	2948	21
1	2948	23
1	2948	24
1	2948	25
1	2949	6
1	2949	7
1	2949	9
1	2949	12
1	2949	13
1	2949	14
1	2949	15
1	2949	16
1	2949	17
1	2949	18
1	2949	20
1	2949	21
1	2949	22
1	2949	23
1	2949	24
1	2950	1
1	2950	3
1	2950	6
1	2950	7
1	2950	8
1	2950	9
1	2950	10
1	2950	13
1	2950	14
1	2950	16
1	2950	17
1	2950	19
1	2950	20
1	2950	22
1	2950	25
1	2951	1
1	2951	3
1	2951	6
1	2951	8
1	2951	9
1	2951	10
1	2951	13
1	2951	15
1	2951	16
1	2951	17
1	2951	18
1	2951	19
1	2951	20
1	2951	21
1	2951	22
1	2952	1
1	2952	2
1	2952	3
1	2952	4
1	2952	5
1	2952	6
1	2952	8
1	2952	9
1	2952	11
1	2952	12
1	2952	16
1	2952	19
1	2952	20
1	2952	21
1	2952	22
1	2953	1
1	2953	3
1	2953	4
1	2953	5
1	2953	7
1	2953	8
1	2953	9
1	2953	13
1	2953	17
1	2953	18
1	2953	19
1	2953	20
1	2953	21
1	2953	22
1	2953	23
1	2954	1
1	2954	2
1	2954	3
1	2954	5
1	2954	7
1	2954	9
1	2954	10
1	2954	12
1	2954	14
1	2954	18
1	2954	19
1	2954	22
1	2954	23
1	2954	24
1	2954	25
1	2955	1
1	2955	2
1	2955	3
1	2955	4
1	2955	6
1	2955	8
1	2955	11
1	2955	12
1	2955	13
1	2955	16
1	2955	17
1	2955	18
1	2955	19
1	2955	23
1	2955	24
1	2956	3
1	2956	5
1	2956	7
1	2956	9
1	2956	14
1	2956	16
1	2956	17
1	2956	18
1	2956	19
1	2956	20
1	2956	21
1	2956	22
1	2956	23
1	2956	24
1	2956	25
1	2957	1
1	2957	2
1	2957	4
1	2957	5
1	2957	7
1	2957	8
1	2957	9
1	2957	10
1	2957	11
1	2957	15
1	2957	17
1	2957	19
1	2957	20
1	2957	21
1	2957	24
1	2958	4
1	2958	6
1	2958	7
1	2958	8
1	2958	10
1	2958	11
1	2958	12
1	2958	13
1	2958	14
1	2958	18
1	2958	20
1	2958	22
1	2958	23
1	2958	24
1	2958	25
1	2959	1
1	2959	3
1	2959	4
1	2959	5
1	2959	8
1	2959	10
1	2959	11
1	2959	14
1	2959	15
1	2959	16
1	2959	20
1	2959	21
1	2959	23
1	2959	24
1	2959	25
1	2960	1
1	2960	2
1	2960	3
1	2960	4
1	2960	5
1	2960	8
1	2960	9
1	2960	11
1	2960	12
1	2960	15
1	2960	16
1	2960	19
1	2960	20
1	2960	23
1	2960	25
1	2961	1
1	2961	3
1	2961	4
1	2961	5
1	2961	7
1	2961	8
1	2961	9
1	2961	10
1	2961	13
1	2961	15
1	2961	17
1	2961	18
1	2961	20
1	2961	23
1	2961	25
1	2962	1
1	2962	3
1	2962	6
1	2962	7
1	2962	9
1	2962	11
1	2962	12
1	2962	14
1	2962	15
1	2962	17
1	2962	18
1	2962	20
1	2962	22
1	2962	24
1	2962	25
1	2963	1
1	2963	2
1	2963	3
1	2963	4
1	2963	9
1	2963	10
1	2963	11
1	2963	12
1	2963	13
1	2963	14
1	2963	15
1	2963	18
1	2963	21
1	2963	24
1	2963	25
1	2964	1
1	2964	3
1	2964	4
1	2964	5
1	2964	7
1	2964	9
1	2964	10
1	2964	11
1	2964	12
1	2964	14
1	2964	18
1	2964	20
1	2964	22
1	2964	23
1	2964	25
1	2965	1
1	2965	3
1	2965	7
1	2965	8
1	2965	10
1	2965	11
1	2965	12
1	2965	14
1	2965	15
1	2965	16
1	2965	17
1	2965	18
1	2965	19
1	2965	23
1	2965	24
1	2966	1
1	2966	3
1	2966	4
1	2966	6
1	2966	7
1	2966	8
1	2966	11
1	2966	12
1	2966	13
1	2966	17
1	2966	18
1	2966	19
1	2966	20
1	2966	22
1	2966	23
1	2967	1
1	2967	2
1	2967	3
1	2967	4
1	2967	6
1	2967	7
1	2967	8
1	2967	9
1	2967	14
1	2967	17
1	2967	18
1	2967	19
1	2967	20
1	2967	22
1	2967	25
1	2968	2
1	2968	4
1	2968	5
1	2968	6
1	2968	7
1	2968	9
1	2968	10
1	2968	13
1	2968	14
1	2968	15
1	2968	18
1	2968	19
1	2968	20
1	2968	21
1	2968	23
1	2969	3
1	2969	4
1	2969	5
1	2969	6
1	2969	9
1	2969	11
1	2969	13
1	2969	17
1	2969	18
1	2969	19
1	2969	20
1	2969	21
1	2969	22
1	2969	23
1	2969	24
1	2970	1
1	2970	2
1	2970	3
1	2970	8
1	2970	9
1	2970	11
1	2970	12
1	2970	13
1	2970	14
1	2970	15
1	2970	18
1	2970	20
1	2970	21
1	2970	22
1	2970	25
1	2971	1
1	2971	2
1	2971	4
1	2971	5
1	2971	10
1	2971	11
1	2971	12
1	2971	14
1	2971	15
1	2971	16
1	2971	17
1	2971	18
1	2971	20
1	2971	21
1	2971	25
1	2972	3
1	2972	4
1	2972	5
1	2972	6
1	2972	8
1	2972	11
1	2972	12
1	2972	13
1	2972	14
1	2972	18
1	2972	19
1	2972	20
1	2972	21
1	2972	24
1	2972	25
1	2973	1
1	2973	2
1	2973	4
1	2973	6
1	2973	8
1	2973	9
1	2973	10
1	2973	11
1	2973	14
1	2973	16
1	2973	17
1	2973	18
1	2973	19
1	2973	20
1	2973	25
1	2974	4
1	2974	6
1	2974	8
1	2974	9
1	2974	10
1	2974	12
1	2974	13
1	2974	14
1	2974	15
1	2974	16
1	2974	18
1	2974	19
1	2974	20
1	2974	21
1	2974	24
1	2975	5
1	2975	8
1	2975	11
1	2975	12
1	2975	13
1	2975	14
1	2975	15
1	2975	16
1	2975	17
1	2975	18
1	2975	20
1	2975	21
1	2975	22
1	2975	23
1	2975	24
1	2976	1
1	2976	2
1	2976	4
1	2976	6
1	2976	8
1	2976	9
1	2976	10
1	2976	12
1	2976	13
1	2976	14
1	2976	17
1	2976	18
1	2976	20
1	2976	21
1	2976	24
1	2977	3
1	2977	5
1	2977	6
1	2977	7
1	2977	8
1	2977	9
1	2977	10
1	2977	11
1	2977	13
1	2977	14
1	2977	18
1	2977	20
1	2977	22
1	2977	24
1	2977	25
1	2978	5
1	2978	6
1	2978	7
1	2978	10
1	2978	12
1	2978	13
1	2978	14
1	2978	15
1	2978	16
1	2978	17
1	2978	20
1	2978	21
1	2978	23
1	2978	24
1	2978	25
1	2979	2
1	2979	4
1	2979	5
1	2979	6
1	2979	8
1	2979	9
1	2979	10
1	2979	11
1	2979	13
1	2979	14
1	2979	19
1	2979	20
1	2979	22
1	2979	24
1	2979	25
1	2980	1
1	2980	2
1	2980	4
1	2980	7
1	2980	8
1	2980	12
1	2980	14
1	2980	15
1	2980	16
1	2980	17
1	2980	19
1	2980	20
1	2980	21
1	2980	24
1	2980	25
1	2981	1
1	2981	2
1	2981	5
1	2981	6
1	2981	9
1	2981	10
1	2981	13
1	2981	14
1	2981	17
1	2981	19
1	2981	20
1	2981	21
1	2981	22
1	2981	24
1	2981	25
1	2982	2
1	2982	6
1	2982	7
1	2982	8
1	2982	10
1	2982	12
1	2982	14
1	2982	15
1	2982	16
1	2982	18
1	2982	19
1	2982	20
1	2982	21
1	2982	23
1	2982	24
1	2983	1
1	2983	2
1	2983	3
1	2983	4
1	2983	6
1	2983	7
1	2983	8
1	2983	9
1	2983	12
1	2983	13
1	2983	15
1	2983	19
1	2983	23
1	2983	24
1	2983	25
1	2984	2
1	2984	3
1	2984	5
1	2984	6
1	2984	7
1	2984	8
1	2984	9
1	2984	13
1	2984	14
1	2984	15
1	2984	18
1	2984	20
1	2984	23
1	2984	24
1	2984	25
1	2985	2
1	2985	3
1	2985	4
1	2985	5
1	2985	7
1	2985	11
1	2985	12
1	2985	14
1	2985	15
1	2985	18
1	2985	19
1	2985	21
1	2985	22
1	2985	24
1	2985	25
1	2986	1
1	2986	3
1	2986	4
1	2986	7
1	2986	10
1	2986	12
1	2986	13
1	2986	14
1	2986	16
1	2986	18
1	2986	19
1	2986	20
1	2986	22
1	2986	23
1	2986	25
1	2987	1
1	2987	3
1	2987	4
1	2987	6
1	2987	7
1	2987	8
1	2987	11
1	2987	12
1	2987	13
1	2987	14
1	2987	15
1	2987	16
1	2987	17
1	2987	18
1	2987	20
1	2988	1
1	2988	3
1	2988	6
1	2988	7
1	2988	9
1	2988	10
1	2988	11
1	2988	12
1	2988	13
1	2988	14
1	2988	17
1	2988	19
1	2988	20
1	2988	22
1	2988	23
1	2989	1
1	2989	2
1	2989	4
1	2989	11
1	2989	12
1	2989	13
1	2989	15
1	2989	16
1	2989	18
1	2989	19
1	2989	20
1	2989	22
1	2989	23
1	2989	24
1	2989	25
1	2990	3
1	2990	4
1	2990	5
1	2990	6
1	2990	10
1	2990	12
1	2990	13
1	2990	16
1	2990	18
1	2990	20
1	2990	21
1	2990	22
1	2990	23
1	2990	24
1	2990	25
1	2991	1
1	2991	2
1	2991	3
1	2991	4
1	2991	5
1	2991	6
1	2991	9
1	2991	11
1	2991	12
1	2991	13
1	2991	14
1	2991	16
1	2991	22
1	2991	23
1	2991	25
1	2992	1
1	2992	4
1	2992	5
1	2992	6
1	2992	8
1	2992	9
1	2992	12
1	2992	14
1	2992	17
1	2992	18
1	2992	19
1	2992	21
1	2992	22
1	2992	23
1	2992	25
1	2993	1
1	2993	2
1	2993	3
1	2993	4
1	2993	5
1	2993	7
1	2993	8
1	2993	12
1	2993	13
1	2993	15
1	2993	16
1	2993	18
1	2993	19
1	2993	24
1	2993	25
1	2994	2
1	2994	3
1	2994	4
1	2994	5
1	2994	8
1	2994	9
1	2994	11
1	2994	13
1	2994	15
1	2994	16
1	2994	17
1	2994	18
1	2994	19
1	2994	20
1	2994	21
1	2995	1
1	2995	2
1	2995	3
1	2995	4
1	2995	6
1	2995	11
1	2995	12
1	2995	16
1	2995	19
1	2995	20
1	2995	21
1	2995	22
1	2995	23
1	2995	24
1	2995	25
1	2996	1
1	2996	2
1	2996	3
1	2996	4
1	2996	5
1	2996	10
1	2996	11
1	2996	14
1	2996	15
1	2996	17
1	2996	18
1	2996	19
1	2996	20
1	2996	22
1	2996	24
1	2997	2
1	2997	3
1	2997	4
1	2997	5
1	2997	7
1	2997	8
1	2997	9
1	2997	11
1	2997	14
1	2997	17
1	2997	19
1	2997	20
1	2997	22
1	2997	23
1	2997	25
1	2998	2
1	2998	6
1	2998	7
1	2998	9
1	2998	10
1	2998	12
1	2998	13
1	2998	14
1	2998	16
1	2998	17
1	2998	18
1	2998	19
1	2998	21
1	2998	23
1	2998	25
1	2999	1
1	2999	2
1	2999	3
1	2999	4
1	2999	7
1	2999	10
1	2999	11
1	2999	13
1	2999	17
1	2999	18
1	2999	19
1	2999	20
1	2999	22
1	2999	24
1	2999	25
1	3000	1
1	3000	2
1	3000	5
1	3000	6
1	3000	9
1	3000	10
1	3000	11
1	3000	12
1	3000	15
1	3000	17
1	3000	18
1	3000	19
1	3000	21
1	3000	24
1	3000	25
1	3001	2
1	3001	4
1	3001	6
1	3001	10
1	3001	11
1	3001	12
1	3001	13
1	3001	14
1	3001	18
1	3001	19
1	3001	20
1	3001	21
1	3001	23
1	3001	24
1	3001	25
1	3002	3
1	3002	4
1	3002	6
1	3002	7
1	3002	8
1	3002	10
1	3002	12
1	3002	14
1	3002	15
1	3002	18
1	3002	19
1	3002	21
1	3002	22
1	3002	23
1	3002	25
1	3003	1
1	3003	2
1	3003	5
1	3003	8
1	3003	9
1	3003	10
1	3003	11
1	3003	13
1	3003	14
1	3003	16
1	3003	18
1	3003	19
1	3003	22
1	3003	23
1	3003	25
1	3004	1
1	3004	4
1	3004	5
1	3004	8
1	3004	9
1	3004	10
1	3004	11
1	3004	12
1	3004	14
1	3004	16
1	3004	18
1	3004	19
1	3004	21
1	3004	24
1	3004	25
1	3005	1
1	3005	2
1	3005	3
1	3005	5
1	3005	7
1	3005	9
1	3005	10
1	3005	12
1	3005	13
1	3005	16
1	3005	18
1	3005	19
1	3005	21
1	3005	24
1	3005	25
1	3006	1
1	3006	3
1	3006	4
1	3006	5
1	3006	6
1	3006	8
1	3006	9
1	3006	10
1	3006	11
1	3006	12
1	3006	15
1	3006	19
1	3006	21
1	3006	23
1	3006	25
1	3007	2
1	3007	3
1	3007	4
1	3007	10
1	3007	11
1	3007	12
1	3007	14
1	3007	15
1	3007	16
1	3007	20
1	3007	21
1	3007	22
1	3007	23
1	3007	24
1	3007	25
1	3008	1
1	3008	2
1	3008	4
1	3008	6
1	3008	7
1	3008	8
1	3008	9
1	3008	10
1	3008	12
1	3008	13
1	3008	15
1	3008	16
1	3008	18
1	3008	19
1	3008	24
1	3009	2
1	3009	3
1	3009	4
1	3009	7
1	3009	9
1	3009	11
1	3009	12
1	3009	14
1	3009	18
1	3009	19
1	3009	20
1	3009	22
1	3009	23
1	3009	24
1	3009	25
1	3010	1
1	3010	2
1	3010	3
1	3010	6
1	3010	7
1	3010	8
1	3010	11
1	3010	12
1	3010	14
1	3010	15
1	3010	16
1	3010	17
1	3010	18
1	3010	20
1	3010	25
1	3011	1
1	3011	2
1	3011	3
1	3011	4
1	3011	5
1	3011	7
1	3011	8
1	3011	9
1	3011	10
1	3011	11
1	3011	13
1	3011	15
1	3011	21
1	3011	23
1	3011	24
1	3012	1
1	3012	2
1	3012	3
1	3012	5
1	3012	6
1	3012	7
1	3012	14
1	3012	15
1	3012	16
1	3012	17
1	3012	20
1	3012	21
1	3012	23
1	3012	24
1	3012	25
1	3013	1
1	3013	2
1	3013	3
1	3013	5
1	3013	7
1	3013	8
1	3013	10
1	3013	11
1	3013	13
1	3013	15
1	3013	17
1	3013	18
1	3013	19
1	3013	21
1	3013	22
1	3014	2
1	3014	5
1	3014	7
1	3014	8
1	3014	9
1	3014	11
1	3014	12
1	3014	13
1	3014	14
1	3014	16
1	3014	17
1	3014	19
1	3014	21
1	3014	23
1	3014	24
1	3015	1
1	3015	3
1	3015	4
1	3015	5
1	3015	6
1	3015	7
1	3015	8
1	3015	10
1	3015	12
1	3015	13
1	3015	14
1	3015	17
1	3015	19
1	3015	20
1	3015	22
1	3016	1
1	3016	3
1	3016	5
1	3016	7
1	3016	8
1	3016	9
1	3016	10
1	3016	11
1	3016	12
1	3016	13
1	3016	18
1	3016	20
1	3016	23
1	3016	24
1	3016	25
1	3017	1
1	3017	2
1	3017	3
1	3017	5
1	3017	6
1	3017	7
1	3017	9
1	3017	11
1	3017	12
1	3017	15
1	3017	16
1	3017	17
1	3017	19
1	3017	20
1	3017	21
1	3018	1
1	3018	2
1	3018	3
1	3018	5
1	3018	9
1	3018	10
1	3018	13
1	3018	15
1	3018	16
1	3018	17
1	3018	20
1	3018	21
1	3018	23
1	3018	24
1	3018	25
1	3019	1
1	3019	2
1	3019	3
1	3019	4
1	3019	6
1	3019	9
1	3019	10
1	3019	11
1	3019	12
1	3019	13
1	3019	16
1	3019	17
1	3019	18
1	3019	20
1	3019	21
1	3020	2
1	3020	3
1	3020	6
1	3020	7
1	3020	10
1	3020	13
1	3020	14
1	3020	15
1	3020	17
1	3020	18
1	3020	19
1	3020	20
1	3020	22
1	3020	23
1	3020	24
1	3021	2
1	3021	4
1	3021	5
1	3021	7
1	3021	8
1	3021	10
1	3021	11
1	3021	12
1	3021	13
1	3021	14
1	3021	19
1	3021	20
1	3021	23
1	3021	24
1	3021	25
1	3022	6
1	3022	7
1	3022	8
1	3022	9
1	3022	10
1	3022	12
1	3022	13
1	3022	14
1	3022	15
1	3022	16
1	3022	17
1	3022	20
1	3022	21
1	3022	23
1	3022	25
1	3023	2
1	3023	3
1	3023	6
1	3023	7
1	3023	10
1	3023	12
1	3023	13
1	3023	15
1	3023	16
1	3023	18
1	3023	20
1	3023	21
1	3023	22
1	3023	23
1	3023	25
1	3024	1
1	3024	2
1	3024	4
1	3024	6
1	3024	7
1	3024	9
1	3024	11
1	3024	12
1	3024	15
1	3024	17
1	3024	19
1	3024	22
1	3024	23
1	3024	24
1	3024	25
1	3025	3
1	3025	4
1	3025	6
1	3025	7
1	3025	8
1	3025	11
1	3025	12
1	3025	13
1	3025	14
1	3025	16
1	3025	19
1	3025	21
1	3025	22
1	3025	23
1	3025	24
1	3026	1
1	3026	2
1	3026	3
1	3026	4
1	3026	5
1	3026	6
1	3026	9
1	3026	10
1	3026	12
1	3026	15
1	3026	16
1	3026	17
1	3026	21
1	3026	22
1	3026	23
1	3027	3
1	3027	5
1	3027	6
1	3027	8
1	3027	11
1	3027	13
1	3027	14
1	3027	15
1	3027	17
1	3027	18
1	3027	19
1	3027	20
1	3027	22
1	3027	23
1	3027	25
1	3028	1
1	3028	2
1	3028	3
1	3028	4
1	3028	6
1	3028	10
1	3028	11
1	3028	15
1	3028	17
1	3028	18
1	3028	19
1	3028	21
1	3028	22
1	3028	24
1	3028	25
1	3029	5
1	3029	6
1	3029	7
1	3029	8
1	3029	9
1	3029	10
1	3029	12
1	3029	13
1	3029	15
1	3029	16
1	3029	17
1	3029	18
1	3029	20
1	3029	22
1	3029	25
1	3030	1
1	3030	3
1	3030	4
1	3030	5
1	3030	6
1	3030	8
1	3030	10
1	3030	13
1	3030	14
1	3030	15
1	3030	17
1	3030	18
1	3030	22
1	3030	24
1	3030	25
1	3031	2
1	3031	3
1	3031	6
1	3031	7
1	3031	8
1	3031	9
1	3031	10
1	3031	11
1	3031	12
1	3031	13
1	3031	14
1	3031	20
1	3031	23
1	3031	24
1	3031	25
1	3032	1
1	3032	2
1	3032	4
1	3032	6
1	3032	7
1	3032	8
1	3032	10
1	3032	11
1	3032	14
1	3032	15
1	3032	17
1	3032	18
1	3032	19
1	3032	23
1	3032	24
1	3033	1
1	3033	2
1	3033	3
1	3033	4
1	3033	6
1	3033	7
1	3033	9
1	3033	10
1	3033	11
1	3033	13
1	3033	15
1	3033	19
1	3033	23
1	3033	24
1	3033	25
1	3034	2
1	3034	3
1	3034	6
1	3034	7
1	3034	8
1	3034	9
1	3034	11
1	3034	12
1	3034	13
1	3034	14
1	3034	16
1	3034	18
1	3034	19
1	3034	22
1	3034	25
1	3035	1
1	3035	5
1	3035	7
1	3035	8
1	3035	9
1	3035	12
1	3035	13
1	3035	14
1	3035	17
1	3035	18
1	3035	20
1	3035	21
1	3035	23
1	3035	24
1	3035	25
1	3036	1
1	3036	4
1	3036	5
1	3036	7
1	3036	8
1	3036	9
1	3036	11
1	3036	13
1	3036	14
1	3036	17
1	3036	18
1	3036	20
1	3036	21
1	3036	22
1	3036	25
1	3037	1
1	3037	2
1	3037	3
1	3037	4
1	3037	7
1	3037	8
1	3037	9
1	3037	10
1	3037	11
1	3037	12
1	3037	15
1	3037	16
1	3037	20
1	3037	22
1	3037	23
1	3038	2
1	3038	3
1	3038	4
1	3038	5
1	3038	11
1	3038	12
1	3038	16
1	3038	17
1	3038	18
1	3038	20
1	3038	21
1	3038	22
1	3038	23
1	3038	24
1	3038	25
1	3039	1
1	3039	2
1	3039	4
1	3039	5
1	3039	6
1	3039	7
1	3039	8
1	3039	10
1	3039	11
1	3039	13
1	3039	18
1	3039	19
1	3039	22
1	3039	24
1	3039	25
1	3040	2
1	3040	3
1	3040	4
1	3040	5
1	3040	7
1	3040	8
1	3040	9
1	3040	10
1	3040	11
1	3040	12
1	3040	14
1	3040	16
1	3040	18
1	3040	20
1	3040	21
1	3041	1
1	3041	3
1	3041	5
1	3041	8
1	3041	9
1	3041	10
1	3041	11
1	3041	12
1	3041	13
1	3041	15
1	3041	16
1	3041	18
1	3041	21
1	3041	22
1	3041	25
1	3042	1
1	3042	3
1	3042	4
1	3042	5
1	3042	7
1	3042	8
1	3042	9
1	3042	10
1	3042	11
1	3042	17
1	3042	19
1	3042	21
1	3042	22
1	3042	24
1	3042	25
1	3043	1
1	3043	2
1	3043	3
1	3043	4
1	3043	8
1	3043	9
1	3043	10
1	3043	12
1	3043	13
1	3043	14
1	3043	15
1	3043	17
1	3043	18
1	3043	24
1	3043	25
1	3044	2
1	3044	3
1	3044	6
1	3044	8
1	3044	9
1	3044	12
1	3044	13
1	3044	16
1	3044	17
1	3044	18
1	3044	19
1	3044	20
1	3044	21
1	3044	22
1	3044	24
1	3045	2
1	3045	3
1	3045	5
1	3045	8
1	3045	9
1	3045	10
1	3045	12
1	3045	15
1	3045	16
1	3045	17
1	3045	18
1	3045	20
1	3045	21
1	3045	23
1	3045	25
1	3046	1
1	3046	3
1	3046	4
1	3046	5
1	3046	6
1	3046	7
1	3046	12
1	3046	13
1	3046	15
1	3046	18
1	3046	20
1	3046	21
1	3046	22
1	3046	23
1	3046	25
1	3047	1
1	3047	2
1	3047	4
1	3047	7
1	3047	8
1	3047	9
1	3047	10
1	3047	11
1	3047	14
1	3047	15
1	3047	17
1	3047	18
1	3047	21
1	3047	24
1	3047	25
1	3048	3
1	3048	4
1	3048	5
1	3048	7
1	3048	8
1	3048	10
1	3048	11
1	3048	16
1	3048	18
1	3048	19
1	3048	20
1	3048	21
1	3048	23
1	3048	24
1	3048	25
1	3049	1
1	3049	2
1	3049	3
1	3049	4
1	3049	5
1	3049	7
1	3049	8
1	3049	9
1	3049	12
1	3049	13
1	3049	14
1	3049	15
1	3049	17
1	3049	19
1	3049	20
1	3050	4
1	3050	5
1	3050	6
1	3050	7
1	3050	8
1	3050	9
1	3050	14
1	3050	18
1	3050	19
1	3050	20
1	3050	21
1	3050	22
1	3050	23
1	3050	24
1	3050	25
1	3051	2
1	3051	3
1	3051	4
1	3051	6
1	3051	9
1	3051	10
1	3051	11
1	3051	12
1	3051	15
1	3051	17
1	3051	18
1	3051	20
1	3051	21
1	3051	22
1	3051	25
1	3052	2
1	3052	3
1	3052	4
1	3052	8
1	3052	9
1	3052	10
1	3052	11
1	3052	14
1	3052	15
1	3052	18
1	3052	19
1	3052	20
1	3052	21
1	3052	23
1	3052	24
1	3053	2
1	3053	4
1	3053	5
1	3053	7
1	3053	8
1	3053	12
1	3053	13
1	3053	14
1	3053	16
1	3053	17
1	3053	18
1	3053	19
1	3053	21
1	3053	22
1	3053	23
1	3054	1
1	3054	2
1	3054	4
1	3054	8
1	3054	9
1	3054	10
1	3054	14
1	3054	15
1	3054	18
1	3054	19
1	3054	20
1	3054	21
1	3054	22
1	3054	23
1	3054	24
1	3055	2
1	3055	3
1	3055	7
1	3055	8
1	3055	9
1	3055	10
1	3055	11
1	3055	12
1	3055	14
1	3055	15
1	3055	17
1	3055	20
1	3055	21
1	3055	22
1	3055	23
1	3056	1
1	3056	2
1	3056	3
1	3056	4
1	3056	5
1	3056	8
1	3056	9
1	3056	15
1	3056	16
1	3056	17
1	3056	19
1	3056	21
1	3056	22
1	3056	23
1	3056	25
1	3057	1
1	3057	3
1	3057	4
1	3057	8
1	3057	11
1	3057	13
1	3057	15
1	3057	16
1	3057	18
1	3057	19
1	3057	20
1	3057	21
1	3057	22
1	3057	23
1	3057	24
1	3058	1
1	3058	2
1	3058	5
1	3058	7
1	3058	8
1	3058	9
1	3058	10
1	3058	13
1	3058	14
1	3058	15
1	3058	16
1	3058	19
1	3058	22
1	3058	24
1	3058	25
1	3059	1
1	3059	3
1	3059	4
1	3059	5
1	3059	7
1	3059	8
1	3059	11
1	3059	12
1	3059	15
1	3059	16
1	3059	18
1	3059	19
1	3059	20
1	3059	21
1	3059	25
1	3060	2
1	3060	4
1	3060	5
1	3060	7
1	3060	8
1	3060	10
1	3060	12
1	3060	13
1	3060	14
1	3060	17
1	3060	19
1	3060	21
1	3060	22
1	3060	24
1	3060	25
1	3061	1
1	3061	2
1	3061	3
1	3061	8
1	3061	9
1	3061	11
1	3061	12
1	3061	13
1	3061	14
1	3061	15
1	3061	17
1	3061	18
1	3061	19
1	3061	20
1	3061	22
1	3062	2
1	3062	4
1	3062	6
1	3062	7
1	3062	8
1	3062	9
1	3062	10
1	3062	11
1	3062	12
1	3062	13
1	3062	17
1	3062	19
1	3062	20
1	3062	24
1	3062	25
1	3063	2
1	3063	4
1	3063	5
1	3063	7
1	3063	8
1	3063	10
1	3063	12
1	3063	14
1	3063	16
1	3063	17
1	3063	18
1	3063	19
1	3063	20
1	3063	21
1	3063	22
1	3064	4
1	3064	5
1	3064	6
1	3064	7
1	3064	10
1	3064	11
1	3064	12
1	3064	13
1	3064	14
1	3064	15
1	3064	17
1	3064	18
1	3064	21
1	3064	23
1	3064	25
1	3065	1
1	3065	6
1	3065	7
1	3065	9
1	3065	10
1	3065	12
1	3065	14
1	3065	15
1	3065	16
1	3065	17
1	3065	20
1	3065	21
1	3065	22
1	3065	23
1	3065	24
1	3066	1
1	3066	3
1	3066	5
1	3066	10
1	3066	11
1	3066	12
1	3066	13
1	3066	14
1	3066	16
1	3066	17
1	3066	19
1	3066	21
1	3066	22
1	3066	23
1	3066	25
1	3067	1
1	3067	2
1	3067	5
1	3067	7
1	3067	8
1	3067	9
1	3067	11
1	3067	13
1	3067	14
1	3067	17
1	3067	19
1	3067	20
1	3067	21
1	3067	22
1	3067	24
1	3068	1
1	3068	2
1	3068	3
1	3068	4
1	3068	5
1	3068	6
1	3068	10
1	3068	11
1	3068	12
1	3068	13
1	3068	14
1	3068	16
1	3068	18
1	3068	19
1	3068	25
1	3069	3
1	3069	4
1	3069	5
1	3069	9
1	3069	11
1	3069	12
1	3069	14
1	3069	15
1	3069	16
1	3069	17
1	3069	19
1	3069	20
1	3069	22
1	3069	23
1	3069	25
1	3070	3
1	3070	5
1	3070	7
1	3070	8
1	3070	10
1	3070	11
1	3070	13
1	3070	14
1	3070	15
1	3070	19
1	3070	20
1	3070	21
1	3070	23
1	3070	24
1	3070	25
1	3071	1
1	3071	2
1	3071	4
1	3071	7
1	3071	8
1	3071	10
1	3071	11
1	3071	12
1	3071	14
1	3071	15
1	3071	17
1	3071	19
1	3071	21
1	3071	23
1	3071	25
1	3072	1
1	3072	2
1	3072	3
1	3072	4
1	3072	5
1	3072	6
1	3072	8
1	3072	11
1	3072	13
1	3072	14
1	3072	15
1	3072	17
1	3072	20
1	3072	21
1	3072	25
1	3073	1
1	3073	2
1	3073	3
1	3073	5
1	3073	7
1	3073	8
1	3073	9
1	3073	10
1	3073	11
1	3073	12
1	3073	16
1	3073	17
1	3073	22
1	3073	24
1	3073	25
1	3074	2
1	3074	3
1	3074	4
1	3074	6
1	3074	7
1	3074	8
1	3074	9
1	3074	10
1	3074	16
1	3074	17
1	3074	19
1	3074	20
1	3074	23
1	3074	24
1	3074	25
1	3075	1
1	3075	3
1	3075	4
1	3075	6
1	3075	7
1	3075	9
1	3075	12
1	3075	13
1	3075	14
1	3075	15
1	3075	16
1	3075	17
1	3075	20
1	3075	22
1	3075	25
1	3076	1
1	3076	2
1	3076	5
1	3076	6
1	3076	7
1	3076	9
1	3076	10
1	3076	12
1	3076	13
1	3076	14
1	3076	16
1	3076	17
1	3076	22
1	3076	24
1	3076	25
1	3077	2
1	3077	5
1	3077	7
1	3077	8
1	3077	9
1	3077	10
1	3077	11
1	3077	12
1	3077	15
1	3077	16
1	3077	17
1	3077	18
1	3077	21
1	3077	22
1	3077	23
1	3078	2
1	3078	6
1	3078	7
1	3078	8
1	3078	9
1	3078	10
1	3078	11
1	3078	13
1	3078	14
1	3078	15
1	3078	19
1	3078	20
1	3078	21
1	3078	22
1	3078	23
1	3079	1
1	3079	2
1	3079	4
1	3079	5
1	3079	6
1	3079	7
1	3079	8
1	3079	10
1	3079	12
1	3079	13
1	3079	14
1	3079	16
1	3079	18
1	3079	24
1	3079	25
1	3080	1
1	3080	3
1	3080	4
1	3080	5
1	3080	6
1	3080	7
1	3080	9
1	3080	10
1	3080	11
1	3080	13
1	3080	15
1	3080	17
1	3080	18
1	3080	20
1	3080	25
1	3081	1
1	3081	2
1	3081	4
1	3081	5
1	3081	6
1	3081	10
1	3081	13
1	3081	15
1	3081	17
1	3081	18
1	3081	19
1	3081	21
1	3081	23
1	3081	24
1	3081	25
1	3082	1
1	3082	3
1	3082	4
1	3082	5
1	3082	6
1	3082	7
1	3082	9
1	3082	10
1	3082	12
1	3082	13
1	3082	17
1	3082	18
1	3082	19
1	3082	21
1	3082	24
1	3083	2
1	3083	4
1	3083	5
1	3083	7
1	3083	8
1	3083	9
1	3083	10
1	3083	11
1	3083	12
1	3083	15
1	3083	18
1	3083	19
1	3083	20
1	3083	21
1	3083	23
1	3084	1
1	3084	2
1	3084	4
1	3084	5
1	3084	9
1	3084	12
1	3084	16
1	3084	17
1	3084	18
1	3084	19
1	3084	20
1	3084	22
1	3084	23
1	3084	24
1	3084	25
1	3085	2
1	3085	3
1	3085	4
1	3085	6
1	3085	7
1	3085	9
1	3085	11
1	3085	12
1	3085	13
1	3085	14
1	3085	15
1	3085	19
1	3085	20
1	3085	24
1	3085	25
1	3086	1
1	3086	3
1	3086	4
1	3086	5
1	3086	6
1	3086	7
1	3086	11
1	3086	12
1	3086	13
1	3086	16
1	3086	17
1	3086	18
1	3086	19
1	3086	21
1	3086	23
1	3087	1
1	3087	2
1	3087	3
1	3087	4
1	3087	5
1	3087	6
1	3087	7
1	3087	10
1	3087	12
1	3087	14
1	3087	17
1	3087	18
1	3087	21
1	3087	24
1	3087	25
1	3088	1
1	3088	2
1	3088	3
1	3088	5
1	3088	9
1	3088	10
1	3088	11
1	3088	13
1	3088	15
1	3088	18
1	3088	20
1	3088	21
1	3088	22
1	3088	23
1	3088	25
1	3089	1
1	3089	2
1	3089	4
1	3089	5
1	3089	8
1	3089	10
1	3089	11
1	3089	12
1	3089	13
1	3089	15
1	3089	18
1	3089	20
1	3089	21
1	3089	22
1	3089	23
1	3090	1
1	3090	3
1	3090	4
1	3090	8
1	3090	10
1	3090	11
1	3090	13
1	3090	14
1	3090	17
1	3090	18
1	3090	19
1	3090	21
1	3090	22
1	3090	23
1	3090	25
1	3091	2
1	3091	4
1	3091	5
1	3091	8
1	3091	9
1	3091	11
1	3091	13
1	3091	14
1	3091	15
1	3091	18
1	3091	19
1	3091	20
1	3091	21
1	3091	24
1	3091	25
1	3092	1
1	3092	4
1	3092	5
1	3092	6
1	3092	8
1	3092	9
1	3092	10
1	3092	13
1	3092	15
1	3092	17
1	3092	20
1	3092	21
1	3092	22
1	3092	23
1	3092	25
1	3093	1
1	3093	2
1	3093	3
1	3093	5
1	3093	6
1	3093	7
1	3093	10
1	3093	12
1	3093	14
1	3093	16
1	3093	17
1	3093	20
1	3093	22
1	3093	24
1	3093	25
1	3094	2
1	3094	3
1	3094	4
1	3094	5
1	3094	6
1	3094	8
1	3094	10
1	3094	12
1	3094	13
1	3094	14
1	3094	15
1	3094	17
1	3094	18
1	3094	21
1	3094	22
1	3095	1
1	3095	2
1	3095	4
1	3095	5
1	3095	6
1	3095	7
1	3095	8
1	3095	10
1	3095	11
1	3095	12
1	3095	19
1	3095	21
1	3095	22
1	3095	23
1	3095	24
1	3096	2
1	3096	3
1	3096	4
1	3096	6
1	3096	9
1	3096	13
1	3096	14
1	3096	15
1	3096	16
1	3096	17
1	3096	19
1	3096	20
1	3096	21
1	3096	22
1	3096	25
1	3097	1
1	3097	2
1	3097	3
1	3097	4
1	3097	7
1	3097	8
1	3097	9
1	3097	12
1	3097	13
1	3097	14
1	3097	15
1	3097	17
1	3097	18
1	3097	20
1	3097	25
1	3098	1
1	3098	2
1	3098	3
1	3098	5
1	3098	6
1	3098	8
1	3098	10
1	3098	11
1	3098	13
1	3098	14
1	3098	15
1	3098	16
1	3098	19
1	3098	21
1	3098	24
1	3099	1
1	3099	5
1	3099	6
1	3099	7
1	3099	8
1	3099	10
1	3099	11
1	3099	12
1	3099	17
1	3099	18
1	3099	20
1	3099	21
1	3099	22
1	3099	23
1	3099	25
1	3100	1
1	3100	2
1	3100	3
1	3100	4
1	3100	6
1	3100	8
1	3100	9
1	3100	10
1	3100	15
1	3100	16
1	3100	18
1	3100	20
1	3100	21
1	3100	22
1	3100	25
1	3101	3
1	3101	8
1	3101	9
1	3101	10
1	3101	11
1	3101	12
1	3101	15
1	3101	17
1	3101	18
1	3101	19
1	3101	20
1	3101	21
1	3101	23
1	3101	24
1	3101	25
1	3102	1
1	3102	8
1	3102	10
1	3102	11
1	3102	12
1	3102	13
1	3102	14
1	3102	15
1	3102	16
1	3102	18
1	3102	19
1	3102	20
1	3102	21
1	3102	24
1	3102	25
1	3103	2
1	3103	5
1	3103	6
1	3103	7
1	3103	8
1	3103	11
1	3103	12
1	3103	13
1	3103	15
1	3103	16
1	3103	17
1	3103	22
1	3103	23
1	3103	24
1	3103	25
1	3104	1
1	3104	2
1	3104	3
1	3104	4
1	3104	5
1	3104	6
1	3104	8
1	3104	9
1	3104	10
1	3104	13
1	3104	15
1	3104	17
1	3104	19
1	3104	24
1	3104	25
1	3105	2
1	3105	4
1	3105	5
1	3105	6
1	3105	8
1	3105	10
1	3105	12
1	3105	14
1	3105	15
1	3105	16
1	3105	17
1	3105	22
1	3105	23
1	3105	24
1	3105	25
1	3106	2
1	3106	3
1	3106	4
1	3106	7
1	3106	10
1	3106	12
1	3106	13
1	3106	14
1	3106	15
1	3106	17
1	3106	19
1	3106	20
1	3106	21
1	3106	22
1	3106	25
1	3107	1
1	3107	2
1	3107	3
1	3107	4
1	3107	5
1	3107	7
1	3107	9
1	3107	10
1	3107	12
1	3107	13
1	3107	16
1	3107	17
1	3107	19
1	3107	23
1	3107	25
1	3108	2
1	3108	3
1	3108	4
1	3108	6
1	3108	7
1	3108	11
1	3108	12
1	3108	13
1	3108	14
1	3108	15
1	3108	18
1	3108	20
1	3108	22
1	3108	23
1	3108	25
1	3109	1
1	3109	3
1	3109	5
1	3109	8
1	3109	9
1	3109	10
1	3109	12
1	3109	15
1	3109	16
1	3109	17
1	3109	18
1	3109	19
1	3109	20
1	3109	21
1	3109	23
1	3110	1
1	3110	3
1	3110	4
1	3110	6
1	3110	9
1	3110	12
1	3110	13
1	3110	14
1	3110	15
1	3110	16
1	3110	18
1	3110	20
1	3110	23
1	3110	24
1	3110	25
1	3111	2
1	3111	3
1	3111	4
1	3111	5
1	3111	7
1	3111	9
1	3111	10
1	3111	12
1	3111	13
1	3111	15
1	3111	16
1	3111	18
1	3111	19
1	3111	22
1	3111	23
1	3112	1
1	3112	2
1	3112	3
1	3112	5
1	3112	7
1	3112	8
1	3112	9
1	3112	11
1	3112	12
1	3112	15
1	3112	16
1	3112	18
1	3112	19
1	3112	20
1	3112	22
1	3113	1
1	3113	3
1	3113	5
1	3113	6
1	3113	8
1	3113	9
1	3113	11
1	3113	14
1	3113	16
1	3113	18
1	3113	21
1	3113	22
1	3113	23
1	3113	24
1	3113	25
1	3114	2
1	3114	3
1	3114	4
1	3114	5
1	3114	6
1	3114	7
1	3114	8
1	3114	10
1	3114	12
1	3114	13
1	3114	14
1	3114	16
1	3114	21
1	3114	23
1	3114	25
1	3115	1
1	3115	3
1	3115	4
1	3115	6
1	3115	9
1	3115	11
1	3115	12
1	3115	13
1	3115	15
1	3115	16
1	3115	18
1	3115	20
1	3115	22
1	3115	24
1	3115	25
1	3116	2
1	3116	3
1	3116	4
1	3116	5
1	3116	7
1	3116	9
1	3116	12
1	3116	14
1	3116	15
1	3116	16
1	3116	19
1	3116	21
1	3116	22
1	3116	23
1	3116	24
1	3117	1
1	3117	2
1	3117	4
1	3117	7
1	3117	9
1	3117	11
1	3117	12
1	3117	15
1	3117	16
1	3117	17
1	3117	18
1	3117	19
1	3117	21
1	3117	22
1	3117	23
1	3118	1
1	3118	6
1	3118	7
1	3118	10
1	3118	11
1	3118	12
1	3118	14
1	3118	15
1	3118	18
1	3118	19
1	3118	21
1	3118	22
1	3118	23
1	3118	24
1	3118	25
1	3119	2
1	3119	4
1	3119	7
1	3119	8
1	3119	9
1	3119	10
1	3119	12
1	3119	14
1	3119	16
1	3119	19
1	3119	21
1	3119	22
1	3119	23
1	3119	24
1	3119	25
1	3120	1
1	3120	3
1	3120	4
1	3120	5
1	3120	7
1	3120	8
1	3120	10
1	3120	11
1	3120	13
1	3120	15
1	3120	16
1	3120	17
1	3120	18
1	3120	19
1	3120	21
1	3121	1
1	3121	2
1	3121	3
1	3121	4
1	3121	6
1	3121	7
1	3121	8
1	3121	11
1	3121	14
1	3121	17
1	3121	19
1	3121	22
1	3121	23
1	3121	24
1	3121	25
1	3122	1
1	3122	2
1	3122	3
1	3122	4
1	3122	7
1	3122	12
1	3122	13
1	3122	15
1	3122	17
1	3122	18
1	3122	19
1	3122	21
1	3122	22
1	3122	23
1	3122	25
1	3123	1
1	3123	3
1	3123	5
1	3123	8
1	3123	9
1	3123	13
1	3123	14
1	3123	15
1	3123	16
1	3123	17
1	3123	21
1	3123	22
1	3123	23
1	3123	24
1	3123	25
1	3124	1
1	3124	3
1	3124	5
1	3124	9
1	3124	12
1	3124	13
1	3124	14
1	3124	15
1	3124	16
1	3124	17
1	3124	19
1	3124	20
1	3124	21
1	3124	22
1	3124	25
1	3125	3
1	3125	5
1	3125	6
1	3125	9
1	3125	10
1	3125	12
1	3125	13
1	3125	14
1	3125	16
1	3125	17
1	3125	18
1	3125	19
1	3125	20
1	3125	21
1	3125	24
1	3126	1
1	3126	4
1	3126	5
1	3126	6
1	3126	7
1	3126	9
1	3126	10
1	3126	13
1	3126	14
1	3126	16
1	3126	19
1	3126	21
1	3126	23
1	3126	24
1	3126	25
1	3127	2
1	3127	3
1	3127	4
1	3127	7
1	3127	12
1	3127	14
1	3127	15
1	3127	16
1	3127	18
1	3127	20
1	3127	21
1	3127	22
1	3127	23
1	3127	24
1	3127	25
1	3128	1
1	3128	2
1	3128	5
1	3128	8
1	3128	9
1	3128	10
1	3128	11
1	3128	13
1	3128	14
1	3128	16
1	3128	17
1	3128	18
1	3128	20
1	3128	21
1	3128	24
1	3129	1
1	3129	2
1	3129	4
1	3129	6
1	3129	7
1	3129	8
1	3129	14
1	3129	15
1	3129	16
1	3129	17
1	3129	18
1	3129	19
1	3129	22
1	3129	23
1	3129	25
1	3130	1
1	3130	2
1	3130	5
1	3130	8
1	3130	9
1	3130	10
1	3130	12
1	3130	13
1	3130	14
1	3130	15
1	3130	16
1	3130	20
1	3130	21
1	3130	22
1	3130	24
1	3131	2
1	3131	3
1	3131	4
1	3131	5
1	3131	6
1	3131	7
1	3131	8
1	3131	9
1	3131	12
1	3131	14
1	3131	17
1	3131	22
1	3131	23
1	3131	24
1	3131	25
1	3132	2
1	3132	3
1	3132	4
1	3132	5
1	3132	7
1	3132	10
1	3132	11
1	3132	13
1	3132	14
1	3132	15
1	3132	16
1	3132	22
1	3132	23
1	3132	24
1	3132	25
1	3133	2
1	3133	5
1	3133	6
1	3133	9
1	3133	10
1	3133	11
1	3133	12
1	3133	14
1	3133	15
1	3133	17
1	3133	19
1	3133	20
1	3133	22
1	3133	24
1	3133	25
1	3134	1
1	3134	3
1	3134	6
1	3134	7
1	3134	8
1	3134	9
1	3134	12
1	3134	13
1	3134	14
1	3134	15
1	3134	18
1	3134	19
1	3134	20
1	3134	21
1	3134	25
\.


--
-- Data for Name: tipo_jogo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_jogo (id_tipo_jogo, nm_tipo_jogo, qt_dezena_resultado, qt_dezena_minima_aposta, qt_dezena_maxima_apota, nm_route) FROM stdin;
1	Lotofácil	15	15	20	portaldeloterias/api/lotofacil/
\.


--
-- Data for Name: tipo_jogo_estrutura; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_jogo_estrutura (id_tipo_jogo, nr_estrutura_jogo) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
1	7
1	8
1	9
1	25
1	10
1	11
1	12
1	13
1	14
1	15
1	16
1	17
1	18
1	19
1	20
1	21
1	22
1	23
1	24
\.


--
-- Data for Name: tipo_jogo_premiacao; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipo_jogo_premiacao (id_tipo_jogo, seq_tipo_jogo, qt_dezena_acerto, vl_premio, ind_valor_variavel) FROM stdin;
1	1	11	6.00	0
1	2	12	12.00	0
1	3	13	30.00	0
1	4	14	\N	1
1	5	15	\N	1
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuario (id_usuario, nm_usuario, ds_email, ds_hashsenha, dt_nascimento, dt_cadastro, ds_numero_celular) FROM stdin;
1	Tiago de Souza	t.souza.1982@gmail.com	teste	1982-11-24	2024-01-24	+5511976359394
\.


--
-- Name: aposta pk_aposta; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aposta
    ADD CONSTRAINT pk_aposta PRIMARY KEY (id_aposta, id_usuario, id_tipo_jogo);


--
-- Name: aposta_item pk_aposta_item; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aposta_item
    ADD CONSTRAINT pk_aposta_item PRIMARY KEY (id_aposta, id_usuario, id_tipo_jogo, nr_aposta);


--
-- Name: ciclo pk_ciclo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciclo
    ADD CONSTRAINT pk_ciclo PRIMARY KEY (id_ciclo, id_tipo_jogo, nr_concurso);


--
-- Name: ciclo_item pk_ciclo_item; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciclo_item
    ADD CONSTRAINT pk_ciclo_item PRIMARY KEY (id_ciclo, id_tipo_jogo, nr_concurso, nr_ausente);


--
-- Name: concurso pk_concurso; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.concurso
    ADD CONSTRAINT pk_concurso PRIMARY KEY (id_tipo_jogo, nr_concurso);


--
-- Name: parametro pk_parametro; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parametro
    ADD CONSTRAINT pk_parametro PRIMARY KEY (id_parametro);


--
-- Name: sorteio pk_sorteio; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sorteio
    ADD CONSTRAINT pk_sorteio PRIMARY KEY (id_tipo_jogo, nr_concurso, nr_sorteado);


--
-- Name: tipo_jogo pk_tipo_jogo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_jogo
    ADD CONSTRAINT pk_tipo_jogo PRIMARY KEY (id_tipo_jogo);


--
-- Name: tipo_jogo_estrutura pk_tipo_jogo_estrutura; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_jogo_estrutura
    ADD CONSTRAINT pk_tipo_jogo_estrutura PRIMARY KEY (id_tipo_jogo, nr_estrutura_jogo);


--
-- Name: tipo_jogo_premiacao pk_tipo_jogo_premiacao; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_jogo_premiacao
    ADD CONSTRAINT pk_tipo_jogo_premiacao PRIMARY KEY (id_tipo_jogo, seq_tipo_jogo);


--
-- Name: usuario pk_usuario; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT pk_usuario PRIMARY KEY (id_usuario);


--
-- Name: ix_tipo_jogo_estrtura_1; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_tipo_jogo_estrtura_1 ON public.tipo_jogo_estrutura USING btree (nr_estrutura_jogo) INCLUDE (nr_estrutura_jogo);


--
-- Name: aposta_item fk_aposta_item_aposta; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aposta_item
    ADD CONSTRAINT fk_aposta_item_aposta FOREIGN KEY (id_aposta, id_usuario, id_tipo_jogo) REFERENCES public.aposta(id_aposta, id_usuario, id_tipo_jogo);


--
-- Name: aposta fk_aposta_tipo_jogo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aposta
    ADD CONSTRAINT fk_aposta_tipo_jogo FOREIGN KEY (id_tipo_jogo) REFERENCES public.tipo_jogo(id_tipo_jogo);


--
-- Name: aposta fk_aposta_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aposta
    ADD CONSTRAINT fk_aposta_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario(id_usuario);


--
-- Name: ciclo fk_ciclo_concurso; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciclo
    ADD CONSTRAINT fk_ciclo_concurso FOREIGN KEY (id_tipo_jogo, nr_concurso) REFERENCES public.concurso(id_tipo_jogo, nr_concurso);


--
-- Name: ciclo_item fk_ciclo_item_ciclo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciclo_item
    ADD CONSTRAINT fk_ciclo_item_ciclo FOREIGN KEY (id_ciclo, id_tipo_jogo, nr_concurso) REFERENCES public.ciclo(id_ciclo, id_tipo_jogo, nr_concurso);


--
-- Name: ciclo fk_ciclo_tipo_jogo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ciclo
    ADD CONSTRAINT fk_ciclo_tipo_jogo FOREIGN KEY (id_tipo_jogo) REFERENCES public.tipo_jogo(id_tipo_jogo);


--
-- Name: concurso fk_concurso_tipo_jogo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.concurso
    ADD CONSTRAINT fk_concurso_tipo_jogo FOREIGN KEY (id_tipo_jogo) REFERENCES public.tipo_jogo(id_tipo_jogo);


--
-- Name: sorteio fk_sorteio_concurso; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sorteio
    ADD CONSTRAINT fk_sorteio_concurso FOREIGN KEY (id_tipo_jogo, nr_concurso) REFERENCES public.concurso(id_tipo_jogo, nr_concurso);


--
-- Name: tipo_jogo_estrutura fk_tipo_jogo_estrutura_tipo_jogo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_jogo_estrutura
    ADD CONSTRAINT fk_tipo_jogo_estrutura_tipo_jogo FOREIGN KEY (id_tipo_jogo) REFERENCES public.tipo_jogo(id_tipo_jogo);


--
-- Name: tipo_jogo_premiacao fk_tipo_jogo_premiacao_tipo_jogo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_jogo_premiacao
    ADD CONSTRAINT fk_tipo_jogo_premiacao_tipo_jogo FOREIGN KEY (id_tipo_jogo) REFERENCES public.tipo_jogo(id_tipo_jogo);


--
-- PostgreSQL database dump complete
--

