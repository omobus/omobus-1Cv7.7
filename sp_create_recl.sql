/* -*- SQL -*- */
/* This file is a part of the omobus-1Cv7.7 project.
 * Copyright (c) 2006 - 2010 ak-obs, Ltd. <info@omobus.ru>.
 * Author: George Kovalenko <george@ak-obs.ru>.
 */
if OBJECT_ID('SP_CREATE_RECL') is not null drop procedure [dbo].[SP_CREATE_RECL]
GO
/****** Object:  StoredProcedure [dbo].[SP_CREATE_RECL]    Script Date: 11/02/2010 11:22:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
Чем заполнять:
 - SP8560 кратность. Как в ордере исп. 1.
 - SP9381 Водитель, бывает пустым, исп. '     0'
 - SP10009 ВключатьВМЛ, бывает  0, исп. 0.
*/
-- declare @iddoc_new char(9), @docno_new char(10)
-- exec SP_CREATE_RECL @id_la = '    B0FIL', @id_c = '    7T000', @del_addr_id = '    35FIL', @docno_prefix = 'МДМ', @id_postfix = 'FIL',
--  @_doc_no_new = @docno_new OUTPUT, @_id_new=@iddoc_new OUTPUT
/*
(C) Copyright ООО "АК ОБС", 2010.
Все имущественные и неимущественные авторские
права законным образом зарегистрированы.
*/
create procedure [dbo].[SP_CREATE_RECL]
    @id_la                  char(9),            /*ТП*/
    @id_c                   char(9),            /*Контрагент*/
    @del_addr_id            char(9),            /*Адрес доставки*/
    @date_recl              datetime,           /*System date as YYYY-MM-DD, current time be added*/
    @docno_prefix           varchar(9),         /*Передавать литералом. ДМЗ Фили = 'МДМ'*/
    @id_postfix             char(3),            /*Передавать литералом. 1C DBUID, '000' = Москва*/
    @firm_id                char(9),            /* Фирма */
    @_doc_no_new            char(10) OUTPUT,
    @_id_new                char(9) OUTPUT
as
declare @rc                 int,
            @id             char(9),
            @iddocdef       char(9),
            @id_stricted    varchar(9),
            @id_new         char(9),
            @id_new_stricted varchar(9),
            @doc_no         char(10),
            @doc_no_new     char(10),
            @doc_no_stricted varchar(10),
            @DOC_NO_L       varchar(10),
            @DOC_NO_J       varchar(10),
            @date           char(8),
            @time           char(8),
            @time36         char(6),
            @date_time_iddoc char(23),
            @dnprefix       char(18),
            @parentval      char(23),
            @query          nvarchar(4000),
            @doc_cnt        int

    -- Общие реквизиты _1sjourn
    declare @SP74           char(9)         /*Автор */
    declare @SP798          char(9)         /*Проект*/
    declare @SP4056         char(9)         /*Фирма */
    declare @SP5365         char(9)         /*ЮрЛицо*/

    -- Рреквизиты документа DH1656
    declare @SP3340         char(9)         /*КодОперации*/
    declare @SP1633         char(13)        /*ДокОснование*/
    declare @SP1639         char(9)         /*Склад*/
    declare @SP1629         char(9)         /*Контрагент*/
    declare @SP1630         char(9)         /*Договор*/
    declare @SP1631         char(9)         /*Валюта*/
    declare @SP1632         numeric(9,4)    /*Курс*/
    declare @SP8560         numeric(7)      /*Кратность*/
    declare @SP1635         numeric(1)      /*УчитыватьНДС*/
    declare @SP1636         numeric(1)      /*СуммаВклНДС*/
    declare @SP1637         numeric(1)      /*УчитыватьНП*/
    declare @SP1638         numeric(1)      /*СуммаВклНП*/
    declare @SP6089         numeric(1)      /*ОблагаетсяЕНВД*/
    declare @SP1641         char(9)         /*ТипЦен*/
    declare @SP7320         char(9)         /*Скидка*/
    declare @SP1640         numeric(14,2)   /*СуммаВзаиморасчет*/
    declare @SP1634         char(8)         /*ДатаОплаты*/
--    declare @SP6397         char(50)        /*НомерДатаСФ*/
    declare @SP8993         numeric(1)      /*ДляОтгрузкиОтДруг*/
    declare @SP9012         numeric(1)      /*ОтказОтПоставки*/
    declare @SP9194         numeric(1)      /*ПризнакМодифицироN*/
    declare @SP9313         char(9)         /*АдресДоставки*/
    declare @SP9379         char(9)         /*Менеджер*/
    declare @SP9380         char(9)         /*ТорговыйПредставиC*/
    declare @SP9381         char(9)         /*Водитель*/
    declare @SP10009        numeric(1)      /*ВключатьВМЛ*/
    declare @SP1649         numeric(14,2)   /*Сумма*/
    declare @SP1650         numeric(14,2)   /*СуммаНДС*/
    declare @SP1651         numeric(14,2)   /*СуммаНП*/
    declare @SP9015         numeric(1)      /*РазрешениеНаРазов*/
    declare @SP660          varchar(11)     /*Комментарий*/

    set nocount on

    /* Сформировать остальные поля для DH и _1SJOURN */
    set @dnprefix = '      1656'+convert(char(4),getdate(),21) + '    '
    set @iddocdef = '1656'
    -- образец подписи системы set @SP1008 = 'SS :VER:'                         /* Основание         */

    -- Определить дефолтные значения
    set @SP3340/*КодОперации*/ = '   15O   '
    set @SP1633/*ДокОснование*/ = '   0     0   '
    select @SP1631/*Валюта*/ = id from SC14 (nolock) where sp18='Российский рубль'
    set @SP1632/*Курс*/ = 1
    set @SP8560/*Кратность*/ = 1
    set @SP1635/*УчитыватьНДС*/ = 1
    set @SP1636/*СуммаВклНДС*/ = 1
    set @SP1637/*УчитыватьНП*/ = 0
    set @SP1638/*СуммаВклНП*/ = 0
    set @SP6089/*ОблагаетсяЕНВД*/ = 0
    set @SP9015/*РазрешениеНаРазов*/ = 0
    set @SP660/*Комментарий*/ = 'PPC created'
    set @SP1640/*СуммаВзаиморасчет*/ = 0
    set @SP7320/*Скидка*/ = '     0'
--    set @SP6397/*НомерДатаСФ*/ = ''
    set @SP1629/*Контрагент*/ = @id_c
    set @SP9379/*Менеджер*/ = '     0'
    set @SP9380/*ТорговыйПредставиC*/ = @id_la
    set @SP9381/*Водитель*/ = '     0'

    select @SP1630/*Договор*/ = SP667 from sc172/*Контрагенты*/ (nolock) where id=@id_c

    set @SP9313/*АдресДоставки*/ = @del_addr_id
    select top 1 @SP798/*Проект*/ = (select top 1 value from _1sconst(nolock)where id=9361 and objid=a.id order by date desc)from SC9293 a(nolock)where a.id=@del_addr_id

    select @SP74/*Автор*/=id, /*@SP798/ *Проект* /=SP5727,*/ @SP4056/*Фирма*/=@firm_id,
        @SP5365/*ЮрЛицо*/=(select sp4011 from SC4014/*Фирмы*/ where id=@firm_id),
        @SP1639/*Склад*/ = SP873, @SP1641/*ТипЦен*/ = SP1954
        from sc30/*Пользователи*/ (nolock) where code = 'PPC_' + @id_postfix

    select @SP1641/*ТипЦен*/ = SP1948 from SC204 (nolock) where id = @SP1630

    set @SP1634/*ДатаОплаты*/ = convert( char(8), getdate(), 112)

    /* Получить дату и время для DATE_TIME_IDDOC */
--  set @date = convert( char(8), getdate(), 112)
    set @date = convert( char(8), @date_recl, 112)
    set @time = right(convert( char(19), getdate(), 21), 8)

    /* Преобразовать рвемя в формат 1С */
--    EXECUTE @rc=master.dbo.xp_MakeTime36 @time, @time36 OUTPUT
    select @time36=dbo.TimeTo36( @time )

    begin tran /* Для удержания X-блокировки на _1sjourn */

        /* Получить макс ID, установив X-блокировку на _1sjourn */
        select @id=MAX(IDDOC) from _1SJOURN(TabLockX)
        set @id_stricted = left(@id, len(@id) - len(@id_postfix))

        /* Получить макс № документа из журнала и таблицы блокировок номеров */
        /* из журнала */
        select @doc_no_l=case when max(docno)is null then replicate(' ',10-len(@docno_prefix)) + '-1' else max(docno)end, @doc_cnt=count(docno) from _1sdnlock (tablockx, holdlock) where left(dnprefix,10)=left( @dnprefix, 10 ) and docno like @docno_prefix + '%'
        /* из таблицы блокировок номеров */
        select @doc_no_j=max(docno) from _1sjourn where iddocdef=@iddocdef and docno like @docno_prefix + '%'
        set @doc_no_stricted = right(@doc_no, len(@doc_no) - len(@docno_prefix))

        /* Отделить цифровые части номеров */
        set @doc_no_l = right(@doc_no_l, len(@doc_no_l) - len(@docno_prefix))
        set @doc_no_j = right(@doc_no_j, len(@doc_no_j) - len(@docno_prefix))

        /* Выбрать макисмальный номер из двух значений */
        set @doc_no_stricted = case when @doc_no_j>@doc_no_l then @doc_no_j else @doc_no_l end

        /* Сформировать новый № документа (IncrementId36) */
        set @doc_no_new = @docno_prefix + replace(str( @doc_no_stricted + 1, len(@doc_no_stricted) ), ' ', '0')
--print '@doc_no_new=''' + @doc_no_new + ''''

        /* Сформировать новый ID документа (IncrementId36) */
--        EXECUTE @rc=master.dbo.xp_IncrementId36 @id_stricted, @id_new_stricted OUTPUT
        select @id_new_stricted=dbo.Inc36( @id_stricted )
        set @id_new = replicate(' ', len(@id) - len(rtrim(ltrim(@id_new_stricted))) - len(@id_postfix)) + rtrim(ltrim(@id_new_stricted)) + @id_postfix

        /* Сформировать DATE_TIME_IDDOC */
        set @date_time_iddoc = @date + @time36 + @id_new

        /* Зарезервировать номер документа - вставить строку в таблицу блокировок номеров документов */
        insert into _1sdnlock (docno, dnprefix)values( @doc_no_new, left( @dnprefix, 10 ))

        -- Insert into JDOC
        select @query=dbo.fn_make_insert( '_1SJOURN', 'SP5365::''' + @SP5365 + ''',, SP4056::''' + @SP4056 + ''',,SP798::''' + @SP798 + ''',,SP74::''' + @SP74 + ''',,IDJOURNAL::4588,,IDDOC::''' + @id_new + ''',,IDDOCDEF::1656,,DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,DNPREFIX::''' + @dnprefix + ''',,DOCNO::''' + @doc_no_new + ''',,APPCODE::1,,VERSTAMP::0,,' )
--print 'Autoformed query:'
--print @query
        exec sp_executesql @statement=@query

    commit  -- отпустить X-блокировку _1sjourn

    /* Удалить запись из таблицы блокировок номеров документов */
    delete from _1sdnlock where docno=@doc_no_new and left(dnprefix,10)=left( @dnprefix, 10 )

    -- Insert into DH1656
    select @query=dbo.fn_make_insert( 'DH1656', 'IDDOC::''' + @id_new + ''',,SP1633::''' + @SP1633 + ''',,SP660::''' + @SP660 + ''',,SP9015::0,,SP1639::''' + @SP1639 + ''',,SP1629::'''+@SP1629+''',,SP1630::'''+@SP1630+''',,SP1631::'''+@SP1631+''',,SP1632::'+rtrim(ltrim(str(@SP1632,9,4)))+',,SP8560::'+rtrim(ltrim(str(@SP8560)))+',,SP1635::'+rtrim(ltrim(str(@SP1635)))+',,SP1636::'+rtrim(ltrim(str(@SP1636)))+',,SP1637::'+rtrim(ltrim(str(@SP1637)))+',,SP1638::'+rtrim(ltrim(str(@SP1638)))+',,SP6089::'+rtrim(ltrim(str(@SP6089)))+
        ',,SP1641::'''+@SP1641+''',,SP7320::'''+@SP7320+''',,SP1640::'+rtrim(ltrim(str(@SP1640,14,2)))+',,SP1634::'''+@SP1634+''',,SP9313::'''+@SP9313+''',,SP9379::'''+@SP9379+''',,SP9380::'''+@SP9380+''',,SP9381::'''+@SP9381+''',,SP3340::'''+@SP3340+''',,')
--print 'Autoformed query:'
--print @query
    exec sp_executesql @statement=@query

    /* Сделать insert'ы в _1SCRDOC */
    /*insert into _1scrdoc -- Журнал отбора по клиентам*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::862,,PARENTVAL::''B1  4S' + case @id_c when null then '     0   ' else @id_c end + ''',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал отбора по складам*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::4747,,PARENTVAL::''B1  1J' + case @SP1639 when null then '     0   ' else @SP1639 end + ''',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал ?*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::8686,,PARENTVAL::''U'',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал ?*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::8875,,PARENTVAL::''U'',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    set @_doc_no_new    = @doc_no_new
    set @_id_new        = @id_new

    select @doc_no_new as doc_num_sys, @id_new as doc_id_sys



GO

