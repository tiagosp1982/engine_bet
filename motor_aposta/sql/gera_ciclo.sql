-- FUNCTION: public.process_sorteio(integer)

-- DROP FUNCTION IF EXISTS public.process_sorteio(integer);

CREATE OR REPLACE PROCEDURE public.gera_ciclo(
	cd_tipo_jogo integer)
	
    LANGUAGE 'plpgsql'
AS $BODY$
 

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
$BODY$;

ALTER PROCEDURE public.gera_ciclo(integer)
    OWNER TO postgres;
