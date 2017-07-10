/* -*- SQL -*- */
/* This file is a part of the omobus-1Cv7.7 project.
 * Copyright (c) 2006 - 2010 ak-obs, Ltd. <info@omobus.ru>.
 * Author: George Kovalenko <george@ak-obs.ru>.
 * License: GPLv2
 */

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

ALTER  FUNCTION [dbo].[FixDateISO] (@in_str char(14))  
RETURNS char(10) AS  
BEGIN 
return substring(@in_str, 0, 5)+'-'+substring(@in_str, 5, 2)+'-'+substring(@in_str, 7, 2);
END
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

