*******************************************************************************;
* Program           : prepare-rasp-for-nsrr.sas
* Project           : National Sleep Research Resource (sleepdata.org)
* Author            : Michael Rueschman (mnr)
* Date Created      : 20210401
* Purpose           : Prepare RASP data for posting on NSRR.
*******************************************************************************;

*******************************************************************************;
* establish options and libnames ;
*******************************************************************************;
  options nofmterr;
  data _null_;
    call symput("sasfiledate",put(year("&sysdate"d),4.)||put(month("&sysdate"d),z2.)||put(day("&sysdate"d),z2.));
  run;

  *project source datasets;
  libname rasps "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_source";

  *output location for nsrr sas datasets;
  libname raspd "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_datasets";
  libname raspa "\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_archive";

  *set data dictionary version;
  %let version = 0.1.0.pre;

  *set nsrr csv release path;
  %let releasepath = \\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_releases;
  %let sourcepath = \\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_source;

*******************************************************************************;
* nimh import ;
*******************************************************************************;
  proc import datafile="&sourcepath\NIMH - subtypes toddler behavioral data.xlsx"
    out=nimh_cov_in
    dbms=xlsx
    replace;
  run;

  proc import datafile="&sourcepath\RASP Data 4-25-22 edits - mnr edits.xlsx"
    out=nimh_dx_in
    dbms=xlsx
    replace;
    sheet="NIMH";
  run;

  /*

  proc freq data=nimh_in;
    table STUDY_GROUP;
  run;

  */

  data nimh_cov;
    set nimh_cov_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = GUID;

    *create edf name;
    edfid = edf;

    *create siteid;
    format siteid $20.;
    siteid = 'nimh';

    *create typical indicator (0=not typical | 1=typical);
    if STUDY_GROUP = "TYPICAL" then typical = 1;
    else typical = 0;

    *create age_years;
    age_years = SLEEP_AGE;

    *create sex_mf;
    *original sex variable: 1=Male | 2=Female;
    if sex = 1 then sex_mf = 'm';
    else if sex = 2 then sex_mf = 'f';

    *set diagnosis columns;
    format diagnosis_1 diagnosis_2 diagnosis_3 diagnosis_4 diagnosis_5
      diagnosis_6 diagnosis_7 diagnosis_8 diagnosis_9 diagnosis_10
      diagnosis_11 diagnosis_12 diagnosis_13 diagnosis_14 $150.;
    diagnosis_1 = lowcase(STUDY_GROUP);

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      diagnosis_1 -- diagnosis_14
      ;
  run;

  /*

  proc sort data=nimh_cov nodupkey;
    by nsrrid;
  run;

  */

  proc sort data=nimh_cov nodupkey;
    by nsrrid age_years;
  run;

  data nimh_final;
    set
      nimh_cov
      ;
  run;

  /*

  proc sql;
    select nsrrid, incov, indx, not_in_both
    from nimh_final
    where not_in_both = 1;
  quit;

  */

*******************************************************************************;
* bch import ;
*******************************************************************************;
  proc import datafile="&sourcepath\BCH - Rasp BCH Subjects .xlsx"
    out=bch_ndd_in
    dbms=xlsx
    replace;
    sheet="NDD Cohort";
  run;

  proc import datafile="&sourcepath\BCH - Rasp BCH Subjects .xlsx"
    out=bch_control_in
    dbms=xlsx
    replace;
    sheet="Control Cohort";
  run;

  proc import datafile="&sourcepath\RASP Data 4-25-22 edits - mnr edits.xlsx"
    out=bch_dx_in
    dbms=xlsx
    replace;
    sheet="BCH";
  run;

  /*

  proc freq data=bch_ndd_in;
    table Age__mo_;
  run;

  */

  data bch_ndd;
    set bch_ndd_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = id;

    *create edf name;
    edfid = nsrrid || "-a.edf";

    *create siteid;
    format siteid $20.;
    siteid = 'bch';

    *create typical indicator (0=not typical | 1=typical);
    *this is NDD / non-control group;
    typical = 0;

    *create age_years;
    *age in months, limited number of cases including "(days)" text;
    if index(Age__mo_,"(days)") then age_years = input(compress(Age__mo_,"(days)"),8.)/30.4/12;
    else age_years = input(Age__mo_,8.) / 12;

    *create sex_mf;
    sex_mf = sex;

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data bch_control;
    set bch_control_in;

    *create nsrrid;
    format nsrrid $30.;
    if input(compress(id,'BCH'),8.) < 100 then nsrrid = "BCH0" || substr(id,4,2);
    else nsrrid = id;

    *create edf name;
    edfid = trim(nsrrid) || "-a.edf";

    *create siteid;
    format siteid $20.;
    siteid = 'bch';

    *create typical indicator (0=not typical | 1=typical);
    *this is typical / control group;
    typical = 1;

    *create age_years;
    *age in months, limited number of cases including "(days)" text;
    age_years = Age__mo_ / 12;

    *create sex_mf;
    sex_mf = sex;

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data bch_cov;
    set
      bch_ndd
      bch_control
      ;

    if nsrrid = '' then delete;
  run;

  proc sort data=bch_cov nodupkey;
    by nsrrid;
  run;

  data bch_dx;
    set bch_dx_in;

    *create nsrrid;
    format nsrrid $30.;
    if substr(id,4,1) in ('0','1') then nsrrid = id;
    else nsrrid = "BCH0" || substr(id,4,2);

    *set diagnosis columns;
    format diagnosis_1 diagnosis_2 diagnosis_3 diagnosis_4 diagnosis_5
      diagnosis_6 diagnosis_7 diagnosis_8 diagnosis_9 diagnosis_10
      diagnosis_11 diagnosis_12 diagnosis_13 diagnosis_14 $150.;

    keep 
      nsrrid
      diagnosis_1 -- diagnosis_14
      ;
  run;

  proc sort data=bch_dx nodupkey;
    by nsrrid;
  run;

  data bch_final;
    merge
      bch_cov
      bch_dx
      ;
    by nsrrid;
  run;

*******************************************************************************;
* geisinger import ;
*******************************************************************************;
  proc import datafile="&sourcepath\Geisinger - For Transfer - Geisinger RASP dataset de-identified.xlsx"
    out=geisinger_cov_in
    dbms=xlsx
    replace;
  run;

  proc import datafile="&sourcepath\RASP Data 4-25-22 edits - mnr edits.xlsx"
    out=geisinger_dx_in
    dbms=xlsx
    replace;
    sheet="Geisinger";
  run;

  data geisinger_cov;
    set geisinger_cov_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = compress(Sub_ID,'-');

    *create edf name;
    edfid = trim(nsrrid) || ".edf";

    *create siteid;
    format siteid $20.;
    siteid = 'geisinger';

    *create typical indicator (0=not typical | 1=typical);
    *Dev_Delay variable included as 'No' | 'Yes';
    if Dev_Delay = "No" then typical = 1;
    else typical = 0;

    *create age_years;
    *only given to integer year, along with including some entries in Months;
    if index(AGE_AT_ENC2,"Months") then age_years = input(compress(AGE_AT_ENC2,"Months"),8.)/12;
    else age_years = input(AGE_AT_ENC2,8.);

    *create sex_mf;
    if PT_SEX = "Male" then sex_mf = 'm';
    else if PT_SEX = "Female" then sex_mf = 'f';

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;  

  data geisinger_dx;
    set geisinger_dx_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = compress(ID,'-');

    *set diagnosis columns;
    format diagnosis_1 diagnosis_2 diagnosis_3 diagnosis_4 diagnosis_5
      diagnosis_6 diagnosis_7 diagnosis_8 diagnosis_9 diagnosis_10
      diagnosis_11 diagnosis_12 diagnosis_13 diagnosis_14 $150.;

    keep
      nsrrid
      diagnosis_1 -- diagnosis_14
      ;
  run;

  proc sort data=geisinger_cov nodupkey;
    by nsrrid;
  run;

  proc sort data=geisinger_dx nodupkey;
    by nsrrid;
  run;

  data geisinger_final;
    merge
      geisinger_cov
      geisinger_dx
      ;
    by nsrrid;
  run;

*******************************************************************************;
* tch import ;
*******************************************************************************;
  proc import datafile="&sourcepath\TCH - Uploadable 51-51 subject-control list.xlsx"
    out=tch_ndd_in
    dbms=xlsx
    replace;
    sheet="51 subjects with NDD";
  run;

  proc import datafile="&sourcepath\TCH - Uploadable 51-51 subject-control list.xlsx"
    out=tch_controls_in
    dbms=xlsx
    replace;
    sheet="51 matched controls";
  run;

  proc import datafile="&sourcepath\RASP Data 4-25-22 edits - mnr edits.xlsx"
    out=tch_dx_in
    dbms=xlsx
    replace;
    sheet="TCH";
  run;

  data tch_ndd_controls_in;
    set
      tch_ndd_in
      tch_controls_in
      ;
  run;

  data tch_ndd;
    set tch_ndd_controls_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = De_identified_ID;

    *create edf name;
    edfid = trim(nsrrid) || ".edf";

    *create siteid;
    format siteid $20.;
    siteid = 'tch';

    *create typical indicator (0=not typical | 1=typical);
    *controls typical, ndd not typical;
    if Neuro_developmental_delay = '' then typical = 1;
    else if Neuro_developmental_delay = 'Y' then typical = 0;

    *create age_years;
    *only given to integer year, along with including some entries in Months;
    if index(Age_at_the_time_of_sleep_study,"months") then age_years = input(compress(Age_at_the_time_of_sleep_study,"months"),8.)/12;
    else if index(Age_at_the_time_of_sleep_study,"mo") then age_years = input(compress(Age_at_the_time_of_sleep_study,"mo"),8.)/12;
    else age_years = input(compress(Age_at_the_time_of_sleep_study,"yo"),8.);

    *create sex_mf;
    if SEX = "M" then sex_mf = 'm';
    else if SEX = "F" then sex_mf = 'f';

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  proc import datafile="&sourcepath\TCH - Uploadable copy 24-24 ASD and control list.xlsx"
    out=tch_asd_all_in
    dbms=xlsx
    replace;
  run;

  data tch_asd_cases;
    set tch_asd_all_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = Study_H_42601_Patient_code;

    *create edf name;
    edfid = trim(nsrrid) || ".edf";

    *create siteid;
    format siteid $20.;
    siteid = 'tch';

    *create typical indicator (0=not typical | 1=typical);
    *controls typical, ndd not typical;
    *all asd cases;
    typical = 0;

    *create age_years;
    *only given to integer year, along with including some entries in Months;
    if index(Age_on_the_day_of_sleep_study,"y.o.") then age_years = input(compress(Age_on_the_day_of_sleep_study,"y.o."),8.);
    else if index(Age_on_the_day_of_sleep_study,"m.o.") then age_years = input(compress(Age_on_the_day_of_sleep_study,"m.o."),8.)/12;
    else age_years = input(compress(Age_on_the_day_of_sleep_study,"yo"),8.);

    *create sex_mf;
    sex_mf = VAR2;

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data tch_asd_controls;
    set tch_asd_all_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = Matched_Control_code;

    *create edf name;
    edfid = trim(nsrrid) || ".edf";

    *create siteid;
    format siteid $20.;
    siteid = 'tch';

    *create typical indicator (0=not typical | 1=typical);
    *controls typical, ndd not typical;
    *all asd controls;
    typical = 1;

    *create age_years;
    *only given to integer year, along with including some entries in Months;
    if index(Controls__age_at_which_sleep_stu,"y.o.") then age_years = input(compress(Controls__age_at_which_sleep_stu,"y.o."),8.);
    else if index(Controls__age_at_which_sleep_stu,"mo") then age_years = input(compress(Controls__age_at_which_sleep_stu,"mo"),8.)/12;
    else age_years = input(compress(Controls__age_at_which_sleep_stu,"yo"),8.);

    *create sex_mf;
    sex_mf = Controls_Sex;

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data tch_asd;
    set
      tch_asd_cases
      tch_asd_controls
      ;
  run;

  data tch_cov;
    set
      tch_asd
      tch_ndd
      ;
  run;

  data tch_dx;
    set tch_dx_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = ID;

    *set diagnosis columns;
    format diagnosis_1 diagnosis_2 diagnosis_3 diagnosis_4 diagnosis_5
      diagnosis_6 diagnosis_7 diagnosis_8 diagnosis_9 diagnosis_10
      diagnosis_11 diagnosis_12 diagnosis_13 diagnosis_14 $150.;

    *only keep rows with an ID;
    if ID ne '';

    keep
      nsrrid
      diagnosis_1 -- diagnosis_14
      ;
  run;

  proc sort data=tch_cov nodupkey;
    by nsrrid;
  run;

  proc sort data=tch_dx nodupkey;
    by nsrrid;
  run;

  data tch_final;
    merge
      tch_cov
      tch_dx
      ;
    by nsrrid;
  run;

*******************************************************************************;
* nyu import ;
*******************************************************************************;
  proc import datafile="&sourcepath\nyu_rasp_redcap_all_data.xlsx"
    out=nyu_cov_in
    dbms=xlsx
    replace;
  run;

  proc import datafile="&sourcepath\RASP Data 4-25-22 edits - mnr edits.xlsx"
    out=nyu_dx_in
    dbms=xlsx
    replace;
    sheet="NYU";
  run;

  data nyu_cov;
    set nyu_cov_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = "patient" || put(record_id,8.);

    *create edf name;
    edfid = trim(nsrrid) || ".edf";

    *create siteid;
    format siteid $20.;
    siteid = 'nyu';

    *create typical indicator (0=not typical | 1=typical);
    *controls typical, ndd not typical;
    if primary_designation = "Normal" then typical = 1;
    else typical = 0;

    *create age_years;
    *only given to integer year, along with including some entries in Months;
    age_years = input(age,8.) / 12;

    *create sex_mf;
    if SEX = 1 then sex_mf = 'm';
    else if SEX = 2 then sex_mf = 'f';

    *only keep rows with sex;
    if sex ne .;

    keep
      nsrrid
      edfid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data nyu_dx;
    set nyu_dx_in;

    *create nsrrid;
    format nsrrid $30.;
    nsrrid = "patient" || compress(input(substr(ID,6,2),8.));

    *set diagnosis columns;
    format diagnosis_1 diagnosis_2 diagnosis_3 diagnosis_4 diagnosis_5
      diagnosis_6 diagnosis_7 diagnosis_8 diagnosis_9 diagnosis_10
      diagnosis_11 diagnosis_12 diagnosis_13 diagnosis_14 $150.;

    *only keep rows with an ID;
    if ID ne '';

    keep
      nsrrid
      diagnosis_1 -- diagnosis_14
      ;
  run;

  proc sort data=nyu_cov nodupkey;
    by nsrrid;
  run;

  proc sort data=nyu_dx nodupkey;
    by nsrrid;
  run;

  data nyu_final;
    merge
      nyu_cov
      nyu_dx
      ;
    by nsrrid;
  run;

*******************************************************************************;
* combine site-level datasets ;
*******************************************************************************;
  data rasp_nsrr;
    length nsrrid $30.;
    set
      nimh_final
      bch_final
      geisinger_final
      tch_final
      nyu_final
      ;

    *apply formats;
    format age_years 8.2;

    *set sex_mf to lowcase;
    sex_mf = lowcase(sex_mf);

    *set diagnosis variables to lowercase;
    diagnosis_1 = lowcase(diagnosis_1);
    diagnosis_2 = lowcase(diagnosis_2);
    diagnosis_3 = lowcase(diagnosis_3);
    diagnosis_4 = lowcase(diagnosis_4);
    diagnosis_5 = lowcase(diagnosis_5);
    diagnosis_6 = lowcase(diagnosis_6);
    diagnosis_7 = lowcase(diagnosis_7);
    diagnosis_8 = lowcase(diagnosis_8);
    diagnosis_9 = lowcase(diagnosis_9);
    diagnosis_10 = lowcase(diagnosis_10);
    diagnosis_11 = lowcase(diagnosis_11);
    diagnosis_12 = lowcase(diagnosis_12);
    diagnosis_13 = lowcase(diagnosis_13);
    diagnosis_14 = lowcase(diagnosis_14);

    *create 'harmonized' diagnosis variables;
    if diagnosis_1 in('asd','autism') or
      diagnosis_2 in('asd','autism') or
      diagnosis_3 in('asd','autism') or
      diagnosis_4 in('asd','autism') or
      diagnosis_5 in('asd','autism') or
      diagnosis_6 in('asd','autism') or
      diagnosis_7 in('asd','autism') or
      diagnosis_8 in('asd','autism') or
      diagnosis_9 in('asd','autism') or
      diagnosis_10 in('asd','autism') or
      diagnosis_11 in('asd','autism') or
      diagnosis_12 in('asd','autism') or
      diagnosis_13 in('asd','autism') or
      diagnosis_14 in('asd','autism') then dx_asd = 1;

    if index(diagnosis_1,'trisomy 21') or
      index(diagnosis_2,'trisomy 21') or
      index(diagnosis_3,'trisomy 21') or
      index(diagnosis_4,'trisomy 21') or
      index(diagnosis_5,'trisomy 21') or
      index(diagnosis_6,'trisomy 21') or
      index(diagnosis_7,'trisomy 21') or
      index(diagnosis_8,'trisomy 21') or
      index(diagnosis_9,'trisomy 21') or
      index(diagnosis_10,'trisomy 21') or
      index(diagnosis_11,'trisomy 21') or
      index(diagnosis_12,'trisomy 21') or
      index(diagnosis_13,'trisomy 21') or
      index(diagnosis_14,'trisomy 21') then dx_trisomy21 = 1;

    label
      nsrrid = "NSRR subject identifier"
      edfid = "EDF filename identifier"
      siteid = "Site identifier"
      typical = "Typical indicator (0 = Not typical | 1 = Typical)"
      age_years = "Age (years)"
      sex_mf = "Sex (m | f)"
      ;
  run;

  proc sort data=rasp_nsrr;
    by nsrrid age_years;
  run;

  data rasp_nsrr_final;
    length nsrrid $30. encounter 8.;
    set rasp_nsrr;
    by nsrrid;

    retain encounter;
    if first.nsrrid then do;
      encounter = 1;
    end;
    else do;
      encounter = encounter + 1;
    end;
  run;

  /*

  *generate master list of diagnoses;
  data rasp_diagnoses;
    set 
      rasp_nsrr (keep=diagnosis_1 rename=(diagnosis_1 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_2 rename=(diagnosis_2 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_3 rename=(diagnosis_3 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_4 rename=(diagnosis_4 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_5 rename=(diagnosis_5 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_6 rename=(diagnosis_6 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_7 rename=(diagnosis_7 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_8 rename=(diagnosis_8 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_9 rename=(diagnosis_9 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_10 rename=(diagnosis_10 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_11 rename=(diagnosis_11 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_12 rename=(diagnosis_12 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_13 rename=(diagnosis_13 = diagnosis_all))
      rasp_nsrr (keep=diagnosis_14 rename=(diagnosis_14 = diagnosis_all))
      ;
  run;

  ods pdf file="\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_checking\rasp-diagnoses-by-freq.pdf";

  proc freq data=rasp_diagnoses order=freq;
    table diagnosis_all;
  run;

  ods pdf close;

  ods pdf file="\\rfawin\BWH-SLEEPEPI-NSRR-STAGING\20200224-rasp\nsrr-prep\_checking\rasp-diagnoses-by-alphabetical.pdf";

  proc freq data=rasp_diagnoses;
    table diagnosis_all;
  run;

  ods pdf close;

  proc freq data=rasp_nsrr;
    table dx_asd dx_trisomy21;
  run;

  */

  /*

  *quick stats;
  ods pdf file="c:\temp\temp.pdf";

  proc sort data=rasp_nsrr nodupkey out=rasp_nsrr_unique;
    by nsrrid;
  run;

  title "RASP: Quick breakdown of site, typical, sex, and age distribution";
  title2 "Among ALL subjects";
  proc freq data=rasp_nsrr_unique;
    table siteid;
    table typical;
    table sex_mf;
    table siteid * typical;
  run;
  title;

  proc means data=rasp_nsrr_unique;
    var age_years;
    class siteid;
  run;

  ods pdf close;

  title "RASP: Quick breakdown of site, typical, and sex distribution";
  title2 "Among subjects age 3-4";
  proc freq data=rasp_nsrr;
    table siteid;
    table typical;
    table sex_mf;
    table siteid * typical;
    where age_years >= 3 and age_years < 5;
  run;
  title;

  ods pdf close;

  */

*******************************************************************************;
* make all variable names lowercase ;
*******************************************************************************;
  options mprint;
  %macro lowcase(dsn);
       %let dsid=%sysfunc(open(&dsn));
       %let num=%sysfunc(attrn(&dsid,nvars));
       %put &num;
       data &dsn;
             set &dsn(rename=(
          %do i = 1 %to &num;
          %let var&i=%sysfunc(varname(&dsid,&i));    /*function of varname returns the name of a SAS data set variable*/
          &&var&i=%sysfunc(lowcase(&&var&i))         /*rename all variables*/
          %end;));
          %let close=%sysfunc(close(&dsid));
    run;
  %mend lowcase;

  %lowcase(rasp_nsrr_final);

  /*

  proc contents data=rasp_nsrr out=rasp_nsrr_contents;
  run;

  */

*******************************************************************************;
* create permanent sas datasets ;
*******************************************************************************;
  data raspd.rasp_nsrr raspa.rasp_nsrr_&sasfiledate;
    set rasp_nsrr_final;
  run;

*******************************************************************************;
* export nsrr csv datasets ;
*******************************************************************************;
  proc export data=rasp_nsrr_final
    outfile="&releasepath\&version\rasp-dataset-&version..csv"
    dbms=csv
    replace;
  run;
