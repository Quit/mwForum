-------------------------------------------------------------------------------
--    mwForum - Web-based discussion forum
--    Copyright (c) 1999-2015 Markus Wichitill
--
--    This program is free software; you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation; either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION group_concat_sfunc(TEXT, INTEGER) 
RETURNS TEXT AS $$
	SELECT CASE 
		WHEN $2 IS NULL THEN $1
		WHEN $1 IS NULL THEN $2::TEXT
		ELSE $1 || ',' || $2::TEXT
	END
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION group_concat_sfunc(TEXT, TEXT) 
RETURNS TEXT AS $$
	SELECT CASE 
		WHEN $2 IS NULL THEN $1
		WHEN $1 IS NULL THEN $2
		ELSE $1 || ',' || $2
	END
$$ LANGUAGE SQL IMMUTABLE;

DROP AGGREGATE IF EXISTS group_concat(INTEGER);
CREATE AGGREGATE group_concat(INTEGER) (
 STYPE = TEXT,
 SFUNC = group_concat_sfunc
);

DROP AGGREGATE IF EXISTS group_concat(TEXT);
CREATE AGGREGATE group_concat(TEXT) (
 STYPE = TEXT,
 SFUNC = group_concat_sfunc
);
