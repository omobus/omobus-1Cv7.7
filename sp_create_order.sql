/* -*- SQL -*- */
/* This file is a part of the omobus-1Cv7.7 project.
 * Copyright (c) 2006 - 2010 ak-obs, Ltd. <info@omobus.ru>.
 * Author: George Kovalenko <george@ak-obs.ru>.
 */
if OBJECT_ID('SP_CREATE_ORDER') is not null drop procedure [dbo].[SP_CREATE_ORDER]
GO
/****** Object:  StoredProcedure [dbo].[SP_CREATE_ORDER]    Script Date: 11/02/2010 11:22:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[SP_CREATE_ORDER]
    @id_la                  char(9),            /*ТП*/
    @id_c                   char(9),            /*Контрагент*/
    @del_addr_id            char(9),            /*Адрес доставки*/
    @docno_prefix           varchar(9),         /*Передавать литералом. ДМЗ Фили = 'МДФ'*/
    @id_postfix             char(3),            /*Передавать литералом. 1C DBUID, '000' = Москва*/
    @firm_id                char(9),            /* Фирма */
    @_doc_no_new            char(10) OUTPUT,
    @_id_new                char(9) OUTPUT
as
declare @rc             int,
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

    -- Рреквизиты документа DH2457
    declare @SP4433         char(13)        /*ДокОснование     */
    declare @SP2621         char(9)         /*БанковскийСчет   */
    declare @SP2434         char(9)         /*Контрагент       */
    declare @SP2435         char(9)         /*Договор          */
    declare @SP2436         char(9)         /*Валюта           */
    declare @SP2437         numeric(9,4)    /*Курс             */
    declare @SP8566         numeric(7,0)    /*Кратность        */
    declare @SP2439         numeric(1,0)    /*УчитыватьНДС     */
    declare @SP2440         numeric(1,0)    /*СуммаВклНДС      */
    declare @SP2441         numeric(1,0)    /*УчитыватьНП      */
    declare @SP2442         numeric(1,0)    /*СуммаВклНП       */
    declare @SP2443         numeric(14,2)   /*СуммаВзаиморасчет*/ -- В post-update, так как нужна сумма документа - просто скопировать ее
    declare @SP2444         char(9)         /*ТипЦен           */
    declare @SP2445         char(9)         /*Скидка           */ -- В post-update из КПК
    declare @SP2438         char(8)         /*ДатаОплаты       */
    declare @SP4434         char(8)         /*ДатаОтгрузки     */
    declare @SP4437         char(9)         /*Склад            */
    declare @SP4760         char(9)         /*ВидОперации      */
    declare @SP7943         char(9)         /*СпособРезервирова*/
    declare @SP8969         char(9)         /*Грузополучатель  */
    declare @SP9004         char(9)         /*ДоговорГрузополуч*/
    declare @SP9221         varchar(1)      /*ЭлДокОборотРПК   */
    declare @SP9315         char(9)         /*АдресДоставки    */
    declare @SP9512         varchar(1)      /*ПричинаРазрешения*/
    declare @SP2451         numeric(14)     /*Сумма            */
    declare @SP2452         numeric(14)     /*СуммаНДС         */
    declare @SP2453         numeric(14)     /*СуммаНП          */
    declare @SP8886         numeric(9)      /*Вес              */
    declare @SP9015         numeric(1)      /*РазрешениеНаРазов*/
    declare @SP660          varchar(1)      /*Комментарий      */ -- В post-update из КПК

    set nocount on

    /* Сформировать остальные поля для DH и _1SJOURN */
    set @dnprefix = '      2457'+convert(char(4),getdate(),21) + '    '
    set @iddocdef = '2457'
    -- образец подписи системы set @SP1008 = 'SS :VER:'                         /* Основание         */

    -- Определить дефолтные значения
    set @SP4433/*ДокОснование*/ = '   0     0   '
    set @SP2621/*БанковскийСчет*/ = '     0'
    select @SP2436/*Валюта*/ = id from SC14 (nolock) where sp18='Российский рубль'
    set @SP2437/*Курс*/ = 1
    set @SP8566/*Кратность*/ = 1
    set @SP2439/*УчитыватьНДС*/ = 1
    set @SP2440/*СуммаВклНДС*/ = 1
    set @SP2441/*УчитыватьНП*/ = 0
    set @SP2442/*СуммаВклНП*/ = 0
    set @SP8969 /*Грузополучатель*/ = '     0'
    set @SP9004 /*ДоговорГрузополуч*/ = '     0'
    set @SP9221 /*ЭлДокОборотРПК*/ = ''
    set @SP7943/*СпособРезервирова*/ = '     0' --'   64R' /*ЗаказыОстаток*/
    set @SP9512/*ПричинаРазрешения*/ = ''
    set @SP9015/*РазрешениеНаРазов*/ = 0
    set @SP660/*Комментарий*/ = 'PPC created'
    set @SP2443/*СуммаВзаиморасчет*/ = 0
    set @SP2445/*Скидка*/ = '     0'


    set @SP2434/*Контрагент*/ = @id_c

    select @SP2435/*Договор*/ = SP667, @SP9315/*АдресДоставки*/ = SP9308, @SP798/*Проект*/ = SP8732, @SP2621/*ОсновнойСчет*/ = SP4137 from sc172/*Контрагенты*/ (nolock) where id=@id_c

    set @SP9315/*АдресДоставки*/ = @del_addr_id
    select top 1 @SP798/*Проект*/ = (select top 1 value from _1sconst(nolock)where id=9361 and objid=a.id order by date desc)from SC9293 a(nolock)where a.id=@del_addr_id

    select @SP74/*Автор*/=id, /*@SP798/ *Проект* /=SP5727,*/ @SP4056/*Фирма */=@firm_id,
        @SP5365/*ЮрЛицо*/=(select sp4011 from SC4014/*Фирмы*/ where id=@firm_id),
        @SP4437/*Склад*/ = SP873, @SP2444/*ТипЦен*/ = SP1954
        from sc30/*Пользователи*/ (nolock) where code = 'PPC_' + @id_postfix

    select @SP2444/*ТипЦен*/ = SP1948 from SC204 (nolock) where id = @SP2435

    set @SP2438/*ДатаОплаты*/ = convert( char(8), getdate(), 112)
    set @SP4434/*ДатаОтгрузки*/ = convert( char(8), getdate(), 112)
    set @SP4760/*ВидОперации*/ = '   3O1' -- 'Перечисление.ВидыОперацийЗаявок.Неподтвержденная'

    /* Получить дату и время для DATE_TIME_IDDOC */
    set @date = convert( char(8), getdate(), 112)
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
        select @query=dbo.fn_make_insert( '_1SJOURN', 'SP5365::''' + @SP5365 + ''',, SP4056::''' + @SP4056 + ''',,SP798::''' + @SP798 + ''',,SP74::''' + @SP74 + ''',,IDJOURNAL::4588,,IDDOC::''' + @id_new + ''',,IDDOCDEF::2457,,DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,DNPREFIX::''' + @dnprefix + ''',,DOCNO::''' + @doc_no_new + ''',,APPCODE::1,,' )
--print 'Autoformed query:'
--print @query
        exec sp_executesql @statement=@query

    commit  -- отпустить X-блокировку _1sjourn

    /* Удалить запись из таблицы блокировок номеров документов */
    delete from _1sdnlock where docno=@doc_no_new and left(dnprefix,10)=left( @dnprefix, 10 )

    -- Insert into DH2457
    select @query=dbo.fn_make_insert( 'DH2457', 'IDDOC::''' + @id_new + ''',,SP4433::''' + @SP4433 + ''',,SP2621::''' + @SP2621 + ''',,SP2434::''' + @SP2434 + ''',,SP2435::''' + @SP2435 + ''',,SP2436::''' + @SP2436 + ''',,SP2444::''' + @SP2444 + ''',,SP2445::''' + @SP2445 + ''',,SP4437::''' + @SP4437 + ''',,SP4760::''' + @SP4760 + ''',,SP7943::''' + @SP7943 + ''',,SP8969::''' + @SP8969 + ''',,SP9004::''' + @SP9004 + ''',,SP9315::''' + @SP9315 + ''',,SP9221::''' + @SP9221 + ''',,SP9512::''' +
            @SP9512 + ''',,SP660::''' + @SP660 + ''',,/*N*/SP2437::' + rtrim(ltrim(str( @SP2437 ))) + ',,SP8566::' + rtrim(ltrim(str( @SP8566 ))) + ',,SP2439::' + rtrim(ltrim(str( @SP2439 ))) + ',,SP2440::' + rtrim(ltrim(str( @SP2440 ))) + ',,SP2441::' + rtrim(ltrim(str( @SP2441 ))) + ',,SP2442::' + rtrim(ltrim(str( @SP2442 ))) + ',,SP2443::' + rtrim(ltrim(str( @SP2443 ))) + ',,SP2451::0,,SP2452::0,,SP2453::0,,SP8886::0,,SP9015::0,,/*D*/SP2438::''' + @SP2438 + ''',,SP4434::''' + @SP4434 + ''',,' )
--print 'Autoformed query:'
--print @query
    exec sp_executesql @statement=@query

    /* Сделать insert'ы в _1SCRDOC */
    /*insert into _1scrdoc -- Журнал отбора по клиентам*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::862,,PARENTVAL::''B1  4S' + case @id_c when null then '     0   ' else @id_c end + ''',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал отбора по складам*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::4747,,PARENTVAL::''B1  1J' + case @SP4437 when null then '     0   ' else @SP4437 end + ''',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал основной*/
    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::8675,,PARENTVAL::''U'',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
    exec sp_executesql @statement=@query

    set @_doc_no_new    = @doc_no_new
    set @_id_new        = @id_new

    select @doc_no_new as doc_num_sys, @id_new as doc_id_sys



GO

