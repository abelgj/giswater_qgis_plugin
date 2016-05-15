




-- Function: SCHEMA_NAME.gw_fct_mincut(character varying)

-- DROP FUNCTION SCHEMA_NAME.gw_fct_mincut(character varying);

CREATE OR REPLACE FUNCTION "SCHEMA_NAME".gw_fct_mincut(IN element_id_arg character varying, IN type_element_arg character varying, OUT node_arg varchar[], OUT arc_arg varchar[], OUT valve_arg varchar[]) AS
$BODY$DECLARE

	node_1_aux	text;
	node_2_aux	text;
	controlValue	integer;
	exists_id	text;
 

BEGIN

--	Search path
	SET search_path = "SCHEMA_NAME", public;

--	Create the temporal table for computing nodes
	DROP TABLE IF EXISTS temp_mincut_node CASCADE;
	CREATE TABLE temp_mincut_node
	(		
		node_id character varying(16) NOT NULL,

--		Force indexed column (for performance)
		CONSTRAINT temp_mincut_node_pkey PRIMARY KEY (node_id)
	);


--	Create the temporal table for computing pipes
	DROP TABLE IF EXISTS temp_mincut_arc CASCADE;
	CREATE TABLE temp_mincut_arc
	(		
		arc_id character varying(16) NOT NULL,

--		Force indexed column (for performance)
		CONSTRAINT temp_mincut_arc_pkey PRIMARY KEY (arc_id)
	);


--	Create the temporal table for computing valves
	DROP TABLE IF EXISTS temp_mincut_valve CASCADE;
	CREATE TABLE temp_mincut_valve
	(		
		valve_id character varying(16) NOT NULL,

--		Force indexed column (for performance)
		CONSTRAINT temp_mincut_valve_pkey PRIMARY KEY (valve_id)
	);


--	The element to isolate could be an arc or a node
	IF type_element_arg = 'arc' THEN

--		Check an existing arc
		SELECT COUNT(*) INTO controlValue FROM arc WHERE arc_id = element_id_arg;
		IF controlValue = 1 THEN

--			Insert arc id
			INSERT INTO temp_mincut_arc VALUES(element_id_arg);
		
--			Run for extremes node
			SELECT node_1, node_2 INTO node_1_aux, node_2_aux FROM arc WHERE arc_id = element_id_arg;


--			Check extreme being a valve
			SELECT COUNT(*) INTO controlValue FROM v_valve WHERE node_id = node_1_aux AND (acessibility = FALSE) AND (broken  = FALSE);
			IF controlValue = 1 THEN

--				Insert valve id
				INSERT INTO temp_mincut_valve VALUES(node_1_aux);
				
			ELSE

--				Compute the tributary area using DFS
				PERFORM gw_fct_mincut_recursive(node_1_aux);

			END IF;


--			Check other extreme being a valve
			SELECT COUNT(*) INTO controlValue FROM v_valve WHERE node_id = node_2_aux AND (acessibility = FALSE) AND (broken  = FALSE);
			IF controlValue = 1 THEN

--				Check if the valve is already computed
				SELECT valve_id INTO exists_id FROM temp_mincut_valve WHERE valve_id = node_2_aux;

--				Compute proceed
				IF NOT FOUND THEN

--					Insert valve id
					INSERT INTO temp_mincut_valve VALUES(node_2_aux);

				END IF;
				
			ELSE

--				Compute the tributary area using DFS
				PERFORM gw_fct_mincut_recursive(node_2_aux);

			END IF;

--		The arc_id was not found			
		ELSE 
			RAISE EXCEPTION 'Nonexistent Arc ID --> %', element_id_arg
			USING HINT = 'Please check your arc table';
		END IF;

	ELSE

--		Check an existing node
		SELECT COUNT(*) INTO controlValue FROM node WHERE node_id = element_id_arg;
		IF controlValue = 1 THEN

--			Compute the tributary area using DFS
			PERFORM gw_fct_mincut_recursive(element_id_arg);

--		The arc_id was not found			
		ELSE 
			RAISE EXCEPTION 'Nonexistent Node ID --> %', node_id_arg
			USING HINT = 'Please check your node table';
		END IF;

	END IF;






--	Convert result to array
	SELECT array_agg(node_id) INTO node_arg FROM temp_mincut_node;
	SELECT array_agg(arc_id) INTO arc_arg FROM temp_mincut_arc;
	SELECT array_agg(valve_id) INTO valve_arg FROM temp_mincut_valve;

--	Delete auxiliar tables
	DROP TABLE IF EXISTS temp_mincut_node CASCADE;
	DROP TABLE IF EXISTS temp_mincut_arc CASCADE;
	DROP TABLE IF EXISTS temp_mincut_valve CASCADE;



		
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION SCHEMA_NAME.gw_fct_mincut(IN character varying, IN character varying, OUT varchar[], OUT varchar[], OUT varchar[])
  OWNER TO geoserver;











-- Function: SCHEMA_NAME.gw_fct_mincut_recursive(character varying)

-- DROP FUNCTION SCHEMA_NAME.gw_fct_mincut_recursive(character varying);

CREATE OR REPLACE FUNCTION "SCHEMA_NAME".gw_fct_mincut_recursive(node_id_arg character varying)
  RETURNS void AS
$BODY$DECLARE
	exists_id character varying;
	rec_table record;
	controlValue	integer;


BEGIN

--	Search path
	SET search_path = "SCHEMA_NAME", public;

--	Check node being a valve
	SELECT node_id INTO exists_id FROM v_valve WHERE node_id = node_id_arg AND (acessibility = FALSE) AND (broken  = FALSE);
	IF FOUND THEN

--		Check if the node is already computed
		SELECT valve_id INTO exists_id FROM temp_mincut_valve WHERE valve_id = node_id_arg;

--		Compute proceed
		IF NOT FOUND THEN

--			Insert valve id
			INSERT INTO temp_mincut_valve VALUES(node_id_arg);

		END IF;

	ELSE
	
--		Check if the node is already computed
		SELECT node_id INTO exists_id FROM temp_mincut_node WHERE node_id = node_id_arg;

--		Compute proceed
		IF NOT FOUND THEN

--			Update value
			INSERT INTO temp_mincut_node VALUES(node_id_arg);
		
--			Loop for all the upstream nodes
			FOR rec_table IN SELECT arc_id, node_1 FROM arc WHERE node_2 = node_id_arg
			LOOP

--				Insert into tables
				SELECT arc_id INTO exists_id FROM temp_mincut_arc WHERE arc_id = rec_table.arc_id;

--				Compute proceed
				IF NOT FOUND THEN
					INSERT INTO temp_mincut_arc VALUES(rec_table.arc_id);
				END IF;

--				Call recursive function weighting with the pipe capacity
				PERFORM gw_fct_mincut_recursive(rec_table.node_1);


			END LOOP;

--			Loop for all the downstream nodes
			FOR rec_table IN SELECT arc_id, node_2 FROM arc WHERE node_1 = node_id_arg
			LOOP
	
--				Insert into tables
				SELECT arc_id INTO exists_id FROM temp_mincut_arc WHERE arc_id = rec_table.arc_id;

--				Compute proceed
				IF NOT FOUND THEN
					INSERT INTO temp_mincut_arc VALUES(rec_table.arc_id);
				END IF;

--				Call recursive function weighting with the pipe capacity
				PERFORM gw_fct_mincut_recursive(rec_table.node_2);

			END LOOP;
	
		END IF;
	END IF;

	RETURN;

		
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION SCHEMA_NAME.gw_fct_mincut_recursive(character varying)
  OWNER TO geoserver;
