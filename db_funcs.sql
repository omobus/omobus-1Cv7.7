/* -*- SQL -*- */
/* This file is a part of the omobus-1Cv7.7 project.
 * Copyright (c) 2006 - 2010 ak-obs, Ltd. <info@omobus.ru>.
 * Author: George Kovalenko <george@ak-obs.ru>.
 * License: GPLv2
 */
if OBJECT_ID('from10to36') is not null drop function [dbo].[from10to36]
GO
/****** Object:  UserDefinedFunction [dbo].[from10to36]    Script Date: 11/02/2010 11:24:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
create function [dbo].[from10to36]

(
    @in_str char(16)
)
RETURNS char(9)
as
begin
    /* convert string from base10 to base36 value */
    declare @s char(9), @mask36 char(36)
    set @mask36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    declare @in_10 numeric(18), @nFul numeric(18), @number0 numeric(18), @v numeric(18), @div numeric(18),
        @i int, @r numeric(18), @r36 numeric(18)
    set @in_10 = cast( @in_str as numeric(18) )

    select @nFul=@in_10, @number0=@in_10, @i=9, @s='', @r36=36, @div = power( @r36, 9 )

    while (@i>=0)
        begin
            set @v = cast( @nFul / @div as int )
                if @v < 1
                    begin
                    if rtrim(@s)=''
                        begin
                            set @i = @i - 1
                            set @div = @div /36
                            continue
                        end
                        else
                        begin
                            set @i = @i - 1
                            set @div = @div /36
                            set @s = rtrim(@s) + '0'
                            continue
                        end
                    end
            set @s = rtrim(@s) + substring( @mask36, @v + 1, 1 )
            set @r = @nFul - @v * @div
            set @nFul = @r
            set @i = @i - 1
            set @div = @div /36
      end
    return replicate( ' ', 9 - len(@s) ) + @s
end

GO

if OBJECT_ID('from36to10') is not null drop function [dbo].[from36to10]
GO
/****** Object:  UserDefinedFunction [dbo].[from36to10]    Script Date: 11/02/2010 11:24:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create function [dbo].[from36to10]
(
	@in_str char(9)
)
RETURNS numeric(18)
as
begin
    /* convert string from base36 to base10 value */
	declare @id10 numeric(18), @id36 char(9), @i smallint, @n_len smallint, @pos smallint, @c char(1), @a smallint
	declare @d36 numeric(18)
	set @d36 = 36
	set @id36 = upper(rtrim(ltrim( @in_str )))
	set @id10 = 0
	set @n_len = len( @id36 )
	set @i = 1
	while @i<= @n_len
		begin
			set @pos = @n_len - @i + 1
			set @c = substring( @id36, @pos, 1 )
			set @a = ascii( @c ) - 48
		    if @a>9 set @a = @a - 7
			set @id10 = @id10 + @a * power( @d36, @i - 1 )
			set @i = @i + 1
		end
	return @id10
end

GO

if OBJECT_ID('TimeTo36') is not null drop function [dbo].[TimeTo36]
GO
/****** Object:  UserDefinedFunction [dbo].[TimeTo36]    Script Date: 11/02/2010 11:23:00 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create function [dbo].[TimeTo36]
/* Переводит datetime-время формата CAST 108 в 1C-значение.
   Пример строки: '12:24:32'
*/
(
	@in_str char(8)
)
RETURNS char(6)
as
begin
	declare @secs_10 numeric(18), @dt datetime
	set @dt = convert( datetime, @in_str, 108 ) -- Date with time only
	set @secs_10 = Datepart( hh, @dt )*3600 + Datepart( n, @dt )*60 + Datepart( ss, @dt )
    return left( ltrim(rtrim(dbo.from10to36( cast( 10000*@secs_10 as char(10) ) ))),6)
end

GO

if OBJECT_ID('TimeTo10') is not null drop function [dbo].[TimeTo10]
GO
/****** Object:  UserDefinedFunction [dbo].[TimeTo10]    Script Date: 11/02/2010 11:23:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create function [dbo].[TimeTo10]
/*
(C) Copyright ООО "АК ОБС", 2010.
Все имущественные и неимущественные авторские
права законным образом зарегистрированы.
*/
/* Переводит 1C-значение DATE_TIME_IDDOC в соответствующее datetime-значение.
   Правая часть строки игнорируется, так что можно передавать все поле DATE_TIME_IDDOC.
*/
(
	@in_str char(14)
)
RETURNS datetime
as
begin
	declare @secs_10 numeric(18), @dt datetime

	set @dt = convert( datetime, left( @in_str, 8), 112 ) -- Date without time
	set @secs_10 = dbo.from36to10( substring( @in_str, 9, 6) ) / 10000 -- Secs
	set @dt = DATEADD(second, @secs_10, @dt)

    return @dt
end

GO

if OBJECT_ID('inc36') is not null drop function [dbo].[inc36]
GO
/****** Object:  UserDefinedFunction [dbo].[inc36]    Script Date: 11/02/2010 11:24:07 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create function [dbo].[inc36]
(
	@in_str char(9)
)
RETURNS char(9)
as
begin
    /* assumes in-string and out-string WITHOUT postfix! */
    /* assumes in-string and out-string WITH leading spaces! */

    /* convert base36 string to base10 value */
    declare @in_10 numeric(18)
    set @in_10 = [dbo].[from36to10]( @in_str )

    /* increment base10 value */
    set @in_10 = @in_10 + 1

    /* convert base10 value to base36 string */
    declare @s char(16), @v char(16)
    set @v = ltrim(cast( @in_10 as char(16) ))
    set @s = [dbo].[from10to36]( @v )
	return rtrim(ltrim(@s))
end
GO

if OBJECT_ID('fn_find_default_by_field_name') is not null drop function [dbo].[fn_find_default_by_field_name]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_find_default_by_field_name]    Script Date: 11/02/2010 11:26:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create function [dbo].[fn_find_default_by_field_name]
(
    @params_list    nvarchar(4000),
    @column_name    nvarchar(128),
    @delimiter      nvarchar(128),
    @eov            nvarchar(128)
)
RETURNS             nvarchar(4000)
    --WITH RETURNS NULL ON NULL INPUT
    BEGIN
        declare @out_value          nvarchar(4000)
        declare @sub_string         nvarchar(4000)
        declare @param_pos          int
        declare @val_begin_pos      int
        declare @val_end_pos        int


        set @out_value = null

        set @param_pos = CHARINDEX( @column_name + @delimiter, @params_list )

        if(@param_pos>0)
            begin
                set @val_begin_pos = @param_pos + len(@column_name) + len(@delimiter)
                set @val_end_pos = CHARINDEX( @eov, @params_list, @val_begin_pos )

                set @out_value = case @val_end_pos when 0 then null else substring( @params_list, @val_begin_pos, @val_end_pos - @val_begin_pos )end
            end

        return @out_value
    end

GO

if OBJECT_ID('fn_make_insert') is not null drop function [dbo].[fn_make_insert]
GO
/****** Object:  UserDefinedFunction [dbo].[fn_make_insert]    Script Date: 11/02/2010 11:25:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE function [dbo].[fn_make_insert]
(
    @in_table_name  nvarchar(128),
    @params_list    nvarchar(4000)
)
RETURNS nvarchar(4000)
    --WITH RETURNS NULL ON NULL INPUT
    BEGIN
        -- result variables
        declare @out_params_list            nvarchar(4000)
        declare @out_values_list            nvarchar(4000)
        declare @out_statement              nvarchar(4000)
        -- fetch variables
        declare @table_name                 nvarchar(128)
        declare @column_name                nvarchar(128)
        declare @column_default             nvarchar(4000)
        declare @is_nullable                varchar(3)
        declare @data_type                  nvarchar(128)
        declare @character_maximum_length   int
        declare @numeric_precision          tinyint
        -- mixed
        declare @cur_row                    tinyint
        declare @cur_pos                    tinyint
        declare @cur_field                  tinyint
        declare @cur_default_values         nvarchar(128)


        declare c_columns cursor local dynamic/*static*/ forward_only read_only
             for select
        	        table_name, column_name, column_default, is_nullable, data_type, character_maximum_length, numeric_precision
                    from information_schema.columns
                    	where table_name=@in_table_name and column_name<>'ROW_ID' order by ordinal_position

        set @out_params_list = ''
        set @out_values_list = ''
        set @cur_default_values = ''

        open c_columns

        FETCH NEXT FROM c_columns into
        	@table_name, @column_name, @column_default, @is_nullable, @data_type, @character_maximum_length, @numeric_precision

        set @cur_row = 1

        while @@fetch_status = 0
        begin

            if('timestamp'<>@data_type)
                begin
                    -- case for ', '
                    set @out_params_list = @out_params_list + case when @out_params_list='' then '' else ', ' end + @column_name

                    -- case for ', '
                    set @out_values_list = @out_values_list + case when @out_values_list='' then '' else ', ' end

                    -- Вызвать fn_find_default_by_field_name: Найти default по имени поля. Если его нет, возвращает NULL
                     set @cur_default_values = --'/*' + @column_name + '.' + @data_type + '=*/' +
                            dbo.fn_find_default_by_field_name( @params_list, @column_name, '::', ',,' )

                    -- Если default не найден, то сконструировать его

--print '@data_type=''' + @data_type + ''''
--print '@column_default=''' + @column_default + ''''

                    if( @cur_default_values is null)
                        if( @column_default is NOT null)
                            set @cur_default_values = --'/*' + @column_name + '.' + @data_type + '(DB default)=*/' +
                                    @column_default
                          else
                            set @cur_default_values = --'/*' + @column_name + '.' + @data_type + '(type default)=*/'
                                +
                            case @data_type
                                when 'image'        then ''''''
                                when 'sql_variant'  then ''''''

                                when 'datetime'     then '''1753-01-01 00:00:00.000'''
                                when 'smalldatetime'then '''1900-01-01'''

                                when 'bigint'       then '0'
                                when 'binary'       then '0'
                                when 'bit'          then '0'
                                when 'decimal'      then '0'
                                when 'float'        then '0'
                                when 'int'          then '0'
                                when 'money'        then '0'
                                when 'numeric'      then '0'
                                when 'real'         then '0'
                                when 'smallint'     then '0'
                                when 'smallmoney'   then '0'
                                when 'tinyint'      then '0'
                                when 'varbinary'    then '0'

                                when 'char'         then case when @character_maximum_length=9 then '''     0''' when @character_maximum_length=13 then '''   0     0''' else '''''' end
                                when 'nchar'        then ''''''
                                when 'ntext'        then ''''''
                                when 'nvarchar'     then ''''''
                                when 'text'         then '''''' /*igor: 2009-04-22*/
                                when 'varchar'      then ''''''
                                when 'xml'          then ''''''
                                else 'type not defined!!'
                            end

                    set @out_values_list = @out_values_list + @cur_default_values
                end

            FETCH NEXT FROM c_columns into
            	@table_name, @column_name, @column_default, @is_nullable, @data_type, @character_maximum_length, @numeric_precision
            set @cur_row = @cur_row + 1
        end

        close c_columns
        deallocate c_columns

        set @out_statement = 'insert into ' + @in_table_name + char(13) + char(9) + '(' + @out_params_list + ')' + char(13) + char(9) + 'values' + char(13) + char(9) + '(' + @out_values_list + ')'
        return @out_statement
    end
GO

if OBJECT_ID('FixProdNames') is not null drop function [dbo].[FixProdNames]
GO
/****** Object:  UserDefinedFunction [dbo].[FixProdNames]    Script Date: 11/02/2010 11:26:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[FixProdNames] (@in_str char(256))
RETURNS char(256) AS
BEGIN
	return
		replace(
		--replace(
		--replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
		replace(
			@in_str,
		'  ', ' '),
		--' "ДМЗ"', ''),
		--' (ДМЗ)', ''),
		'нектар', 'нект'),
		'абрикосовый', 'абр'),
		'молочный', 'мол'),
		'молоком', 'мол'),
		'молоко', 'мол'),
		'1,0 л', '1 л'),
		'мультифруктовый', 'м/фрукт'),
		'мультифрукт', 'м/фрукт'),
		'апельсиновый', 'апел'),
		'апельсин', 'апел'),
		'малина', 'мал'),
		'клубника', 'клуб'),
		'персик', 'пер'),
		'маракуйя', 'мар'),
		'красный виноград', 'кр/вин'),
		'ананасовый', 'анан'),
		'ананас', 'анан'),
		'яблоко', 'ябл'),
		'яблочный', 'ябл'),
		'сливочный', 'сл'),
		'фруктовый', 'фр'),
		'глазированный', 'гл'),
		'творожный', 'тв'),
		'Творожная', 'Тв.'),
		'шоколад', 'шок'),
		'сгущенка', 'сгущ'),
		'сгущенкой', 'сгущ'),
		'сгущёнкой', 'сгущ'),
		'Тв. масса', 'Тв/м'),
		'Тв.масса', 'Тв/м'),
		'Масса твор', 'Тв/м'),
		'Масса твороженная', 'Тв/м'),
		'пастеризованное', 'паст.')
	;
END
GO

