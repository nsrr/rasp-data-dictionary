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
* import datasets ;
*******************************************************************************;
  proc import datafile="&sourcepath\NIMH - subtypes toddler behavioral data.xlsx"
    out=nimh_in
    dbms=xlsx
    replace;
  run;

  /*

  proc freq data=nimh_in;
    table STUDY_GROUP;
  run;

  */

  data nimh;
    set nimh_in;

    *create nsrrid;
    nsrrid = GUID;

    *create siteid;
    siteid = 'nimh';

    *create typical indicator (0=not typical | 1=typical);
    if STUDY_GROUP = "TYPICAL" then typical = 1;
    else typical = 0;

    *create age_years;
    age_years = SLEEP_AGE;

    *create sex_mf;
    *original sex variable: 1=Male | 2=Female;
    if sex = 1 then sex_mf = 'M';
    else if sex = 2 then sex_mf = 'F';

    keep
      nsrrid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

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

  /*

  proc freq data=bch_ndd_in;
    table Age__mo_;
  run;

  */

  data bch_ndd;
    set bch_ndd_in;

    *create nsrrid;
    nsrrid = id;

    *create siteid;
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
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data bch_control;
    set bch_control_in;

    *create nsrrid;
    nsrrid = id;

    *create siteid;
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
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data bch;
    set
      bch_ndd
      bch_control
      ;

    if nsrrid = '' then delete;
  run;

  proc import datafile="&sourcepath\Geisinger - For Transfer - Geisinger RASP dataset de-identified.xlsx"
    out=geisinger_in
    dbms=xlsx
    replace;
  run;

  data geisinger;
    set geisinger_in;

    *create nsrrid;
    nsrrid = Sub_ID;

    *create siteid;
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
    if PT_SEX = "Male" then sex_mf = 'M';
    else if PT_SEX = "Female" then sex_mf = 'F';

    keep
      nsrrid
      siteid
      typical
      age_years
      sex_mf
      ;
  run;  

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

  data tch_ndd_controls_in;
    set
      tch_ndd_in
      tch_controls_in
      ;
  run;

  data tch_ndd;
    set tch_ndd_controls_in;

    *create nsrrid;
    nsrrid = De_identified_ID;

    *create siteid;
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
    if SEX = "M" then sex_mf = 'M';
    else if SEX = "F" then sex_mf = 'F';

    keep
      nsrrid
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
    nsrrid = Study_H_42601_Patient_code;

    *create siteid;
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
      siteid
      typical
      age_years
      sex_mf
      ;
  run;

  data tch_asd_controls;
    set tch_asd_all_in;

    *create nsrrid;
    nsrrid = Matched_Control_code;

    *create siteid;
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

  proc import datafile="&sourcepath\nyu_rasp_redcap_all_data.xlsx"
    out=nyu_in
    dbms=xlsx
    replace;
  run;

  data nyu;
    set nyu_in;

    *create nsrrid;
    nsrrid = "patient" || put(record_id,8.);

    *create siteid;
    siteid = 'nyu';

    *create typical indicator (0=not typical | 1=typical);
    *controls typical, ndd not typical;
    *not immediately available;

    *create age_years;
    *only given to integer year, along with including some entries in Months;
    age_years = input(age,8.) / 12;

    *create sex_mf;
    if SEX = 1 then sex_mf = 'M';
    else if SEX = 2 then sex_mf = 'F';

    *only keep rows with sex;
    if sex ne .;

    keep
      nsrrid
      siteid
      age_years
      sex_mf
      ;
  run;

  *combine datasets;
  data rasp_nsrr;
    set
      nimh
      bch
      geisinger
      tch_ndd
      tch_asd
      nyu
      ;

    *apply formats;
    format age_years 8.2;

    label
      nsrrid = "NSRR subject identifier"
      siteid = "Site identifier"
      typical = "Typical indicator (0 = Not typical | 1 = Typical)"
      age_years = "Age (years)"
      sex_mf = "Sex (M | F)"
      ;
  run;

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

  %lowcase(rasp_nsrr);

  /*

  proc contents data=rasp_nsrr out=rasp_nsrr_contents;
  run;

  */

*******************************************************************************;
* create permanent sas datasets ;
*******************************************************************************;
  data raspd.rasp_nsrr raspa.rasp_nsrr_&sasfiledate;
    set rasp_nsrr;
  run;

*******************************************************************************;
* export nsrr csv datasets ;
*******************************************************************************;
  proc export data=rasp_nsrr
    outfile="&releasepath\&version\rasp-dataset-&version..csv"
    dbms=csv
    replace;
  run;
