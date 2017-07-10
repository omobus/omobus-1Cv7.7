/* -*- SQL -*- */
/* This file is a part of the omobus-1Cv7.7 project.
 * Copyright (c) 2006 - 2010 ak-obs, Ltd. <info@omobus.ru>.
 * Author: George Kovalenko <george@ak-obs.ru>.
 * License: GPLv2
 */
if OBJECT_ID('SP_CREATE_ELEMENT') is not null drop procedure [dbo].[SP_CREATE_ELEMENT]
GO
/****** Object:  StoredProcedure [dbo].[SP_CREATE_ELEMENT]    Script Date: 11/02/2010 11:20:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
Добавляет новый элемент в справочник
*/
create procedure [dbo].[SP_CREATE_ELEMENT]
(
    @in_table_name  nvarchar(128),
    @id_new         char(9) OUTPUT
)
as
    declare
        @rc             int,
        @id_name        varchar(32),
        @id             char(9),
        @max_id_t       char(9),
        @max_id_c       char(9),
        @id_stricted    varchar(9),
        @id_new_stricted varchar(6),
        @query          nvarchar(4000),
        @id_len         tinyint,
        @id_postfix     varchar(3),
        @parmdefinition nvarchar(500),
        @docdef         smallint,
        @maxid          char(9)

    set nocount on

    select @id_postfix = dbsign from _1ssystem
    set @docdef = substring(@in_table_name,3, len(@in_table_name)-2)
-- print 'substring(@in_table_name,3, len(@in_table_name)-2)=''' + substring(@in_table_name,3, len(@in_table_name)-2) + ''''
-- print '@docdef=''' + @docdef + ''''

    begin tran /* Для удержания X-блокировки на _1suidctrl */

        /* Получить макс ID, установив X-блокировку */
        -- get max ID from control table
        select @max_id_c=maxid from _1suidctl (TabLockX) where typeid = @docdef and right(maxid,3) = @id_postfix
        set @max_id_c = left(case when @max_id_c is null then '     0' else @max_id_c end, 9)
-- print '@max_id_c = ''' + @max_id_c + ''''

        -- get max ID from table
        set @parmdefinition = N'@postfix char(3), @max_id char(9) output';
        set @query = 'select @max_id = max(left(id,9)) from ' + @in_table_name + '(TabLockX) where right(id,3) = @postfix'
        exec sp_executesql @query, @parmdefinition, @postfix = @id_postfix, @max_id = @max_id_t OUTPUT
        set @max_id_t = case when @max_id_t is null then '     0' else @max_id_t end
-- print '@max_id_t = ''' + @max_id_t + ''''

        -- drop postfix - MANDATORY!
        set @id_stricted = left(case when @max_id_t>@max_id_c then @max_id_t else @max_id_c end, 6)
-- print '@id_stricted = ''' + @id_stricted + ''''

--        EXECUTE @rc=master.dbo.xp_IncrementId36 @id_stricted, @id_new_stricted OUTPUT
        select @id_new_stricted=dbo.Inc36( @id_stricted )

-- print '@id_new_stricted = ''' + @id_new_stricted + ''''
--        set @id_new_stricted = right(@id_new_stricted, 6)
        set @id_new_stricted = rtrim(ltrim( @id_new_stricted ))
-- print '@id_new_stricted = ''' + @id_new_stricted + ''''

        set @id_new = REPLICATE(' ', 6 - len(@id_new_stricted)) + @id_new_stricted + @id_postfix
-- print '@id_new = ''' + @id_new + ''''

        -- Insert into @in_table_name
        select @query=dbo.fn_make_insert( @in_table_name, 'ID::''' + @id_new + ''',,SP10388::getdate(),,')
-- print @query


--print 'Autoformed query:'
--print @query
        exec sp_executesql @statement=@query

        select @maxid = maxid from _1suidctl where typeid=@docdef
-- print '@maxID = ''' + @maxID + ''''
        if @maxid is null
            begin
                insert into _1suidctl (typeid, maxid)values (@docdef, @id_new)
-- print 'inserted'
            end
          else
            begin
                update _1suidctl set maxid= @id_new where typeid= @docdef and maxid= @maxid
-- print 'UPDATED'
            end

    commit  -- отпустить X-блокировку _1sjourn

    /* Данные для УРИБ */
    insert into _1supdts /*dbsign,typeid,objid,deleted,dwnldid*/
        select '000', substring(@in_table_name, 3, len(@in_table_name)-2), @id_new, '', ''

    select @id_new as doc_id_sys

GO

