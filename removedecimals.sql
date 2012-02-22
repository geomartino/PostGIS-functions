-- Function: removedecimals(character varying)

-- DROP FUNCTION removedecimals(character varying);

CREATE OR REPLACE FUNCTION removedecimals(character varying)
  RETURNS character varying AS
$BODY$
DECLARE
    wkt_no_decimal character varying;
    wkt_part varchar;
    wkt_array varchar[];
    pos_dot int;
    pos_coma int;
    pos_parenthesis int;
BEGIN
	wkt_no_decimal := '';
	-- Call example: select removedecimals('POLYGON((-8460281.46802028 5700582.35136436,-8488110.54792657 5700582.64409253,-8460281.46802028 5700582.35136436))');
	
	-- Split the wkt string based on group of whitespace delimiter
	SELECT regexp_split_to_array($1, E'\\s+') INTO wkt_array;

	FOR i IN 1..array_length(wkt_array, 1) LOOP 
		wkt_part := wkt_array[i];

		-- remove substring from dot "." to right parenthesis ")" while keeping the parenthesis: 
		-- ex: '5700582.35136436))' become '5700582))'
		pos_dot := strpos(wkt_part  ,'.');
		pos_parenthesis := strpos(wkt_part , ')');
		if (pos_parenthesis > 0) THEN
		   wkt_part := overlay(wkt_part placing '' from pos_dot for (pos_parenthesis-pos_dot));
		END IF;

		-- remove substring from dot "." to coma "," while keeping the coma: 
		-- ex: '5700582.64409253,-8460281.46802028' become '5700582,-8460281.46802028'
		pos_dot := strpos(wkt_part  ,'.');
		pos_coma := strpos(wkt_part , ',');
		if (pos_coma > 0 and pos_dot < pos_coma) THEN
		   wkt_part := overlay(wkt_part placing '' from pos_dot for (pos_coma-pos_dot));
		END IF;		

		-- remove substring from dot "." to the end of the current part: 
		-- ex: 'POLYGON((-8460281.46802028' become 'POLYGON((-8460281'
		pos_dot := strpos(wkt_part, '.');
		if (pos_dot > 0) THEN
		   wkt_part := overlay(wkt_part placing '' from (pos_dot) for (length(wkt_part )-pos_dot)+1);
		END IF;		

		-- Rebuild a wkt string with no decimal(adding space delimiter)
		-- Return example: 'POLYGON((-8460281 5700582,-8488110 5700582,-8460281 5700582))');
		wkt_no_decimal := wkt_no_decimal || wkt_part || ' ';

	END LOOP; 
  
    return wkt_no_decimal;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION removedecimals(character varying) OWNER TO admgeo;
