CREATE OR REPLACE FUNCTION buildpolycanutec (in_y DOUBLE PRECISION,
                                             in_x DOUBLE PRECISION,
                                              in_epsg INTEGER,
                                              in_direction DOUBLE PRECISION,
                                              in_dist_isolation integer,
                                              in_dist_aval integer,
                                              in_usr varchar(50),
                                              in_publish boolean)
 RETURNS geometry AS
$BODY$
--/******************************************************************************************
--D Description: Build a CANUTEC Geometry base on Wind direction and x,y point
--A Argus     : in_y = coodinate x
--              in_x = coordonnée x
--              in_epsg = SRID off your cordinate
--              in_direction = direction of wind
--              in_dist_isolation = radius of the circular buffer around the point in meters
--              in_dist_aval = radius of the circular buffer to guide the direction of the cone
--              in_usr = user name 
--              in_publish = wms option
--O Output : A CANUTEC Geometry.
-- Spec :  http://wwwapps.tc.gc.ca/saf-sec-sur/3/erg-gmu/gmu/modedemploistdiiap.aspx#2
--H History: Simon Mercier
-- Blog post : http://simonmercier.net/blog/?p=923
--******************************************************************************************/
DECLARE
 geom_buff_isolation geometry ;
 geom_cone_canutec geometry ;
 geom_buff_en_aval geometry ;
 geom_canutec geometry;
 geom_poly_canutec geometry;
 geom_line_translate geometry;
 str_poly_canu varchar(1000);
 x_pts float;
 y_pts float;
 proj_trav integer;
BEGIN
 
 --We will use the SRID Lambert conformal projection which preserve area.
 proj_trav:=32198;
 
 --transform in meters cordinate.
 select into x_pts ST_XMin(ST_Transform(ST_GeomFromText('POINT('||in_x||' '||in_y||')',in_epsg),proj_trav));
 select into y_pts ST_YMin(ST_Transform(ST_GeomFromText('POINT('||in_x||' '||in_y||')',in_epsg),proj_trav));
 
 --build a WKT for the cone
 str_poly_canu:='MULTIPOLYGON (((' || x_pts ||' '|| y_pts+in_dist_isolation ||','|| x_pts + in_dist_aval||' '|| y_pts + (in_dist_aval/2) ||','|| x_pts + in_dist_aval||' '|| y_pts - (in_dist_aval/2) ||','|| x_pts||' '|| y_pts-in_dist_isolation ||','|| x_pts||' '|| y_pts+in_dist_isolation || ')))';
 
 --create the cone Geometry
 select into geom_cone_canutec ST_GeomFromText(str_poly_canu,proj_trav);
 
 --need a buffer isolation geometry
 select into geom_buff_isolation ST_Buffer(ST_GeomFromText('POINT('||x_pts||' '||y_pts||')',proj_trav), in_dist_isolation);

--need a downstream geometry
 select into geom_buff_en_aval ST_Buffer(ST_GeomFromText('POINT('||x_pts||' '||y_pts||')',proj_trav), in_dist_aval);
 
 --trim the cone geometry with the downstream geometry
 select into geom_canutec ST_Intersection(geom_cone_canutec,geom_buff_en_aval);
 
 -- add the isolation buffer zone
 select into geom_canutec ST_Union(geom_canutec,geom_buff_isolation);
 
 -- need to rotate depending on the wind.   Function ST_Rotate PostGIS uses an original 0.0 to rotate geometry.
 -- To work around this problem, I have found a post on the net that works well. Simply rotate the geometry 
 -- and move according to its DeltaX and DeltaY. We will then calculate the DeltaX and DeltaY line with the 
 -- linestring length in_dist_aval.
 -- http://geospatial.nomad-labs.com/2007/02/24/rotation-in-postgis/
 select into geom_line_translate ST_GeomFromText('LINESTRING('||x_pts||' '||y_pts||','||x_pts+in_dist_aval||' '||y_pts||')',proj_trav);
 select into geom_line_translate translate( rotate( translate( geom_line_translate, -x(centroid(geom_line_translate)), -y(centroid(geom_line_translate)) ), radians(in_direction)), x(centroid(geom_line_translate)), y(centroid(geom_line_translate)) );
 
 --rotate geometry on its centroid
 select into geom_poly_canutec translate( rotate( translate( geom_canutec, -x(centroid(geom_canutec)), -y(centroid(geom_canutec)) ), radians(in_direction)), x(centroid(geom_canutec)), y(centroid(geom_canutec)) );
 
 --Finally, apply translation from geom_line_translate.
 select into geom_poly_canutec ST_Multi(translate(geom_poly_canutec,x_pts - ST_XMin(ST_StartPoint(geom_line_translate)), y_pts - ST_YMin(ST_StartPoint(geom_line_translate))));
 
 return geom_poly_canutec;
END;
$BODY$
 LANGUAGE 'plpgsql' VOLATILE


