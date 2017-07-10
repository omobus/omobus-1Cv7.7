/* -*- SQL -*- */
/* This file is a part of the omobus-1Cv7.7 project.
 * Copyright (c) 2006 - 2010 ak-obs, Ltd. <info@omobus.ru>.
 * Author: George Kovalenko <george@ak-obs.ru>.
 */
if OBJECT_ID('SP_CREATE_NC') is not null drop procedure [dbo].[SP_CREATE_NC]
GO
/****** Object:  StoredProcedure [dbo].[SP_CREATE_NC]    Script Date: 11/02/2010 11:21:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[SP_CREATE_NC]
    @id_la                  char(9),            /*ТП*/
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
            @doc_no         char(5),
            @doc_no_new     char(5),
            @doc_no_stricted varchar(5),
            @DOC_NO_L       varchar(5),
            @DOC_NO_J       varchar(5),
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
    declare @SP4437         char(9)         /*Склад            */
    declare @SP9919         char(13)        /*ОператорКПК*/
    declare @SP9920         varchar(64)        /*ИмяКонтрагент*/
    declare @SP9921         varchar(256)       /*ИмяАдресДоставки*/
    declare @SP9922         varchar(128)       /*ИмяЮрАдрес*/
    declare @SP9923         varchar(20)        /*ИНН*/
    declare @SP9924         numeric(1)      /*Состояние*/
    declare @SP9015         numeric(1)      /*РазрешениеНаРазов*/
    declare @SP660          varchar(16)     /*Комментарий      */ -- В post-update из КПК

    set nocount on

    /* Сформировать остальные поля для DH и _1SJOURN */
    set @dnprefix = '      9926'+convert(char(4),getdate(),21) + '    '
    set @iddocdef = '9926'
    -- образец подписи системы set @SP1008 = 'SS :VER:'                         /* Основание         */

    -- Определить дефолтные значения
    set @SP4437/*Склад*/ = '     0000'
    set @SP9919/*ОператорКПК*/ = ' 77W' + @id_la
    set @SP9920/*ИмяКонтрагент*/ = ''
    set @SP9921/*ИмяАдресДоставки*/ = ''
    set @SP9922/*ИмяЮрАдрес*/ = ''
    set @SP9923/*ИНН*/ = ''
    set @SP9924/*Состояние*/ = 0
    set @SP9015/*РазрешениеНаРазов*/ = 0
    set @SP660/*Комментарий*/ = 'PPC created'

    select @SP74/*Автор*/=id, @SP798/*Проект*/=SP5727, @SP4056/*Фирма */=@firm_id,
        @SP5365/*ЮрЛицо*/=(select sp4011 from SC4014/*Фирмы*/ where id=sp4010)--,
--      @SP4437/*Склад*/ = SP873, @SP2444/*ТипЦен*/ = SP1954
        from sc30/*Пользователи*/ (nolock) where code = 'PPC_' + @id_postfix

    /* Получить дату и время для DATE_TIME_IDDOC */
    set @date = convert( char(8), getdate(), 112)
    set @time = right(convert( char(19), getdate(), 21), 8)

    /* Преобразовать рвемя в формат 1С */
    --execute @rc=master.dbo.xp_MakeTime36 @time, @time36 OUTPUT
    select @time36=dbo.TimeTo36( @time )

    begin tran /* Для удержания X-блокировки на _1sjourn */

        /* Получить макс ID, установив X-блокировку на _1sjourn */
        select @id=MAX(IDDOC) from _1SJOURN(TabLockX)
        set @id_stricted = left(@id, len(@id) - len(@id_postfix))
--print '@id=''' + case when @id is null then 'NULL' else @id end + ''''
--print '@id_stricted=''' + case when @id_stricted is null then 'NULL' else @id_stricted end + ''''

--print '@docno_prefix=''' + case when @docno_prefix is null then 'NULL' else @docno_prefix end + ''''
        /* Получить макс № документа из журнала и таблицы блокировок номеров */
        /* из таблицы блокировок номеров */
        select @doc_no_l=case when max(docno)is null then replicate(' ',5-1-len(@docno_prefix)) + '0' else max(docno)end, @doc_cnt=count(docno) from _1sdnlock (tablockx, holdlock) where left(dnprefix,10)=left( @dnprefix, 10 ) and docno like @docno_prefix + '%'
--print '@doc_no_l=''' + case when @doc_no_l is null then 'NULL' else @doc_no_l end + ''''
        /* из журнала */
        select @doc_no_j=max(docno) from _1sjourn where iddocdef=@iddocdef and docno like @docno_prefix + '%'
--print '@doc_no_j=''' + case when @doc_no_j is null then 'NULL' else @doc_no_j end + ''''

        /* Отделить цифровые части номеров */
        set @doc_no_l = right(@doc_no_l, len(@doc_no_l) - len(@docno_prefix))
        set @doc_no_j = right(@doc_no_j, len(@doc_no_j) - len(@docno_prefix))

        /* Выбрать макисмальный номер из двух значений */
        if(@doc_no_j is null and @doc_no_l is NOT null)
            set @doc_no_stricted = @doc_no_l
          else if(@doc_no_l is null and @doc_no_j is NOT null)
            set @doc_no_stricted = @doc_no_j
          else
            set @doc_no_stricted = case when @doc_no_j>@doc_no_l then @doc_no_j else @doc_no_l end
--print '@doc_no_stricted=''' + case when @doc_no_stricted is null then 'NULL' else @doc_no_stricted end + ''''

        /* Сформировать новый № документа (IncrementId36) */
        set @doc_no_new = @docno_prefix + replace(str( @doc_no_stricted + 1, len(@doc_no_stricted) ), ' ', ' ')
--print '@doc_no_new=''' + case when @doc_no_new is null then 'NULL' else @doc_no_new end + ''''

        /* Сформировать новый ID документа (IncrementId36) */
--        execute @rc=master.dbo.xp_IncrementId36 @id_stricted, @id_new_stricted OUTPUT
        select @id_new_stricted=dbo.Inc36( @id_stricted )
        set @id_new = replicate(' ', len(@id) - len(rtrim(ltrim(@id_new_stricted))) - len(@id_postfix)) + rtrim(ltrim(@id_new_stricted)) + @id_postfix
--print '@id_new=''' + case when @id_new is null then 'NULL' else @id_new end + ''''

        /* Сформировать DATE_TIME_IDDOC */
        set @date_time_iddoc = @date + @time36 + @id_new

        /* Зарезервировать номер документа - вставить строку в таблицу блокировок номеров документов */
--print    'insert into _1sdnlock (docno, dnprefix)values( ''' + @doc_no_new + ''', left( ''' + @dnprefix + ''', 10 ))'
        insert into _1sdnlock (docno, dnprefix)values( @doc_no_new, left( @dnprefix, 10 ))

        -- Insert into JDOC
        select @query=dbo.fn_make_insert( '_1SJOURN', 'SP5365::''' + @SP5365 + ''',, SP4056::''' + @SP4056 + ''',,SP798::''' + @SP798 + ''',,SP74::''' + @SP74 + ''',,IDJOURNAL::4588,,IDDOC::''' + @id_new + ''',,IDDOCDEF::9926,,DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,DNPREFIX::''' + left(@dnprefix,10) + ''',,DOCNO::''' + @doc_no_new + ''',,APPCODE::0,,VERSTAMP::1,,' )
--print 'Autoformed query:'
--print @query
        exec sp_executesql @statement=@query

    commit  -- отпустить X-блокировку _1sjourn

    /* Удалить запись из таблицы блокировок номеров документов */
    delete from _1sdnlock where docno=@doc_no_new and left(dnprefix,10)=left( @dnprefix, 10 )
--print 'IDDOC::''' + @id_new + ''',,SP9919::''' + @SP9919 + ''',,SP9920::''' + @SP9920 + ''',,SP9921::''' + @SP9921 + ''',,SP9922::''' + @SP9922 + ''',,SP9923::''' + @SP9923 + ''',,SP9924::''' + ltrim(str(@SP9924)) + ''',,' +
--            'SP660::''' + @SP660 + ''',,SP9015::''' + ltrim(str(@SP9015)) + ''',,'
    -- Insert into DH9926
    select @query=dbo.fn_make_insert( 'DH9926', 'IDDOC::''' + @id_new + ''',,SP9919::''' + @SP9919 + ''',,SP9920::''' + @SP9920 + ''',,SP9921::''' + @SP9921 + ''',,SP9922::''' + @SP9922 + ''',,SP9923::''' + @SP9923 + ''',,SP9924::''' + ltrim(str(@SP9924)) + ''',,' +
            'SP660::''' + @SP660 + ''',,SP9015::''' + ltrim(str(@SP9015)) + ''',,' )
--print 'Autoformed query:'
--print @query
    exec sp_executesql @statement=@query

    /* Сделать insert'ы в _1SCRDOC */
    /*insert into _1scrdoc -- Журнал отбора по клиентам*/
--    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::862,,PARENTVAL::''B1  4S' + case @id_c when null then '     0   ' else @id_c end + ''',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
--print 'Autoformed query:'
--print @query
--    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал отбора по складам*/
--    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::4747,,PARENTVAL::''B1  1J' + case @SP4437 when null then '     0   ' else @SP4437 end + ''',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
--print 'Autoformed query:'
--print @query
--    exec sp_executesql @statement=@query

    /*insert into _1scrdoc -- Журнал основной*/
--    select @query=dbo.fn_make_insert( '_1scrdoc', 'MDID::8675,,PARENTVAL::''U'',,CHILD_DATE_TIME_IDDOC::''' + @date_time_iddoc + ''',,CHILDID::''' + @id_new + ''',,FLAGS::1,,' )
--print 'Autoformed query:'
--print @query
--    exec sp_executesql @statement=@query

    /* Данные для УРИБ */
    insert into _1supdts /*dbsign,typeid,objid,deleted,dwnldid*/
        select '000', 9926, @id_new, '', ''

    set @_doc_no_new    = @doc_no_new
    set @_id_new        = @id_new

    select @doc_no_new as doc_num_sys, @id_new as doc_id_sys



GO

