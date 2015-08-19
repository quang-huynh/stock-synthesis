FUNCTION void get_initial_conditions()
  {
  //*********************************************************************
  /*  SS_Label_Function_23 #get_initial_conditions */
  natage.initialize();
  catch_fleet.initialize();
  annual_catch.initialize();
  annual_F.initialize();
  if(SzFreq_Nmeth>0) SzFreq_exp.initialize();

  //  SS_Label_Info_23.1 #call biology and selectivity functions for the initial year
  //  SS_Label_Info_23.1.1 #These rate are calculated once in PRELIMINARY_CALCS_SECTION, so only recalculate if active according to MG_active
  y=styr;
  yz=styr;
  t_base=styr-1;
  if(MG_active(0)>0 || save_for_report>0) get_MGsetup();
  if(do_once==1) cout<<" MG setup OK "<<endl;
  if(MG_active(2)>0) get_growth1();   // seasonal effects and CV
  if(do_once==1) cout<<" growth OK"<<endl;
  if(MG_active(2)>0 || save_for_report>0)
  {
    ALK_subseas_update=1;  //  to indicate that all ALKs need calculation
    if(Grow_type!=2)
    {get_growth2();}
    else
    {get_growth2_Richards();}
  }
  if(do_once==1) cout<<" growth OK"<<endl;
  if(MG_active(1)>0) get_natmort();
  if(do_once==1) cout<<" natmort OK"<<endl;
  if(MG_active(3)>0) get_wtlen();
  if(MG_active(4)>0) get_recr_distribution();
  if(MG_active(5)>0) get_migration();
  if(MG_active(7)>0)  
  {
    get_catch_mult(y, catch_mult_pointer);
    for(j=styr+1;j<=YrMax;j++)
    {
      catch_mult(j)=catch_mult(y);
    }
  }
  if(do_once==1) cout<<" migr OK"<<endl;
  if(Use_AgeKeyZero>0)
  {
    if(MG_active(6)>0) get_age_age(Use_AgeKeyZero,AgeKey_StartAge,AgeKey_Linear1,AgeKey_Linear2); //  call function to get the age_age key
    if(do_once==1) cout<<" ageerr_key OK"<<endl;
  }

  if(save_for_report>0) get_saveGparm();
  if(do_once==1) cout<<" growth OK, ready to call selex "<<endl;

  //  SS_Label_Info_23.2 #Calculate selectivity in the initial year
  get_selectivity();
  if(do_once==1) cout<<" selex OK, ready to call ALK and fishselex "<<endl;

  //  SS_Label_Info_23.3 #Loop seasons and subseasons
  for (s=1;s<=nseas;s++)
  {
    t = styr+s-1;
    if(MG_active(2)>0 || MG_active(3)>0 || save_for_report>0 || WTage_rd>0)  //  initial year; if growth parms are active, get growth 
    {  
      for(subseas=1;subseas<=N_subseas;subseas++)  //  do all subseasons in first year
      {
        ALK_idx=(s-1)*N_subseas+subseas;
  //  SS_Label_Info_23.3.1 #calculate mean size-at-age, then size_at_age distribution (ALK)
        get_growth3(s, subseas);
        Make_AgeLength_Key(s, subseas);
      }

//  SPAWN-RECR:   call Make_Fecundity()
      if(s==spawn_seas)
      {
        subseas=spawn_subseas;
        ALK_idx=(s-1)*N_subseas+subseas;
        // growth3 already done for all subseas
  //  SS_Label_Info_23.3.2 #in spawn_seas, calculate fecundity-at-age (fec)
        Make_Fecundity();
      }
    }

    for (g=1;g<=gmorph;g++)
    if(use_morph(g)>0)
    {
  //  SS_Label_Info_23.3.3 #for each platoon, combine size_at_age distribution with length selectivity to get combined seelectivity vectors
      Make_FishSelex();
    }
  }

  if(do_once==1) cout<<" ready for virgin age struc "<<endl;
  //  SS_Label_Info_23.4 #calculate unfished (virgin) numbers-at-age
  eq_yr=styr-2;
  bio_yr=styr;
  Fishon=0;
  virg_fec = fec;

//  SPAWN-RECR:   get expected recruitment globally or by area
  if(recr_dist_area==1 || pop==1)  //  do global spawn_recruitment calculations
  {
    Recr_virgin=mfexp(SR_parm(1));
    equ_Recr=Recr_virgin;
    exp_rec(eq_yr,1)=Recr_virgin;  //  expected Recr from s-r parms
    exp_rec(eq_yr,2)=Recr_virgin; 
    exp_rec(eq_yr,3)=Recr_virgin; 
    exp_rec(eq_yr,4)=Recr_virgin;
  
    Do_Equil_Calc();                      //  call function to do equilibrium calculation
    SPB_virgin=SPB_equil;
    Mgmt_quant(1)=SPB_equil;
    if(Do_Benchmark>0)
    {
      Mgmt_quant(2)=totbio;
      Mgmt_quant(3)=smrybio;
      Mgmt_quant(4)=Recr_virgin;
    }
  
    SPB_pop_gp(eq_yr)=SPB_equil_pop_gp;   // dimensions of pop x N_GP
    if(Hermaphro_Option>0) MaleSPB(eq_yr)=MaleSPB_equil_pop_gp;
    SPB_yr(eq_yr)=SPB_equil;
    t=styr-2*nseas-1;
    for (p=1;p<=pop;p++)
    for (g=1;g<=gmorph;g++)
    for (s=1;s<=nseas;s++)
    {natage(t+s,p,g)(0,nages)=equ_numbers(s,p,g)(0,nages);}
  }
  else  //  area-specific spawn-recruitment
  {
    
  }

  //  SS_Label_Info_23.5  #Calculate equilibrium using initial F
  if(do_once==1) cout<<" ready for initial age struc "<<endl;
   eq_yr=styr-1;
   bio_yr=styr;
   if(fishery_on_off==1) {Fishon=1;} else {Fishon=0;}
   for (s=1;s<=nseas;s++)
   {
     t=styr-nseas-1+s;
     for (f=1;f<=Nfleet;f++)
     {
       if(init_F_loc(s,f)>0) {Hrate(f,t) = init_F(init_F_loc(s,f));}
     }
   }
   
  //  SS_Label_Info_23.5.1  #Apply adjustments to the recruitment level
//  SPAWN-RECR:   adjust recruitment for the initial equilibrium
  if(SR_parm_1(N_SRparm2-1,5)>-999)  //  using the PR_type as a flag
  {
  //  SS_Label_Info_23.5.1.1  #Adjustments do not include spawner-recruitment function
   R1_exp=Recr_virgin;
   exp_rec(eq_yr,1)=R1_exp;
   if(SR_env_target==2) {R1_exp*=mfexp(SR_parm(N_SRparm2-2)* env_data(eq_yr,SR_env_link));}
   exp_rec(eq_yr,2)=R1_exp;
   exp_rec(eq_yr,3)=R1_exp;
   R1 = R1_exp*mfexp(SR_parm(N_SRparm2-1));
   exp_rec(eq_yr,4)=R1;

   equ_Recr=R1;
   Do_Equil_Calc();
   CrashPen += Equ_penalty;
  }
  else
  {
    //  SS_Label_Info_23.5.1.2  #Adjustments do include spawner-recruitment function
    //  do initial equilibrium with R1 based on offset from spawner-recruitment curve, using same approach as the benchmark calculations
    //  first get SPR for this init_F
//  SPAWN-RECR:   calc initial equilibrium pop, SPB, Recruitment
    equ_Recr=Recr_virgin;
    Do_Equil_Calc();
    CrashPen += Equ_penalty;
  
    SPR_temp=SPB_equil/equ_Recr;  //  spawners per recruit at initial F
  //  next the rquilibrium SSB and recruitment from SPR_temp
    Equ_SpawnRecr_Result = Equil_Spawn_Recr_Fxn(SR_parm(2), SR_parm(3), SPB_virgin, Recr_virgin, SPR_temp);  //  returns 2 element vector containing equilibrium biomass and recruitment at this SPR
  
    R1_exp=Equ_SpawnRecr_Result(2);     //  set the expected recruitment equal to this equilibrium
    exp_rec(eq_yr,1)=R1_exp;
    if(SR_env_target==2) {R1_exp*=mfexp(SR_parm(N_SRparm2-2)* env_data(eq_yr,SR_env_link));}  //  adjust for environment
    exp_rec(eq_yr,2)=R1_exp;
    exp_rec(eq_yr,3)=R1_exp;
  
    equ_Recr = R1_exp*mfexp(SR_parm(N_SRparm2-1));  // apply R1 offset
    R1=equ_Recr;
    exp_rec(eq_yr,4)=equ_Recr;
  
    Do_Equil_Calc();  // calculated SPB_equil
    CrashPen += Equ_penalty;
  }

   SPB_pop_gp(eq_yr)=SPB_equil_pop_gp;   // dimensions of pop x N_GP
   if(Hermaphro_Option>0) MaleSPB(eq_yr)=MaleSPB_equil_pop_gp;
   SPB_yr(eq_yr)=SPB_equil;
   SPB_yr(styr)=SPB_equil;

   for (s=1;s<=nseas;s++)
   for (f=1;f<=Nfleet;f++)
   {
     if(catchunits(f)==1)
     {
      est_equ_catch(s,f)=equ_catch_fleet(2,s,f);
    }
    else
     {
      est_equ_catch(s,f)=equ_catch_fleet(5,s,f);
     }
   }
   if(save_for_report>0)
   {
     for (s=1;s<=nseas;s++)
     {
       t=styr-nseas-1+s;
       for (f=1;f<=Nfleet;f++)
       {
         for (g=1;g<=6;g++) {catch_fleet(t,f,g)=equ_catch_fleet(g,s,f);}  // gets all 6 elements
         for (g=1;g<=gmorph;g++)
         {catage(t,f,g)=value(equ_catage(s,f,g)); }
       }
     }
   }


   for (s=1;s<=nseas;s++)
   {
     t=styr-nseas-1+s;
     a=styr-1+s;
     for (p=1;p<=pop;p++)
     for (g=1;g<=gmorph;g++)
     {
       natage(t,p,g)(0,nages)=equ_numbers(s,p,g)(0,nages);
       natage(a,p,g)(0,nages)=equ_numbers(s,p,g)(0,nages);
     }
   }

   if(docheckup==1) echoinput<<" init age comp for styr "<<styr<<endl<<natage(styr)<<endl<<endl;

   // if recrdevs start before styr, then use them to adjust the initial agecomp
   //  apply a fraction of the bias adjustment, so bias adjustment gets less linearly as proceed back in time
   if(recdev_first<styr)
   {
     for (p=1;p<=pop;p++)
     for (g=1;g<=gmorph;g++)
     for (a=styr-recdev_first; a>=1; a--)
     {
       j=styr-a;
       natage(styr,p,g,a) *=mfexp(recdev(j)-biasadj(j)*half_sigmaRsq);
     }
   }
   SPB_pop_gp(styr)=SPB_pop_gp(styr-1);  //  placeholder in case not calculated early in styr
   //  note:  the above keeps SPB_pop_gp(styr) = SPB_equil.  It does not adjust for initial agecomp, but probably should
  }  //  end initial_conditions

  //*********************************************************************
FUNCTION void get_time_series()
  {
  /*  SS_Label_Function_24 get_time_series */
  dvariable crashtemp; dvariable crashtemp1;
  dvariable interim_tot_catch;
  dvariable Z_adjuster;
  if(Do_Morphcomp) Morphcomp_exp.initialize();

  //  SS_Label_Info_24.0 #Retrieve spawning biomass and recruitment from the initial equilibrium 
//  SPAWN-RECR:   begin of time series, retrieve last spbio and recruitment
  SPB_current = SPB_yr(styr);  //  need these initial assignments in case recruitment distribution occurs before spawnbio&recruits
  if(recdev_doit(styr-1)>0)
  { Recruits = R1 * mfexp(recdev(styr-1)-biasadj(styr-1)*half_sigmaRsq); }
  else
  { Recruits = R1;}

  //  SS_Label_Info_24.1 #Loop the years
  for (y=styr;y<=endyr;y++)
  {
    yz=y;
    if(STD_Yr_Reverse_F(y)>0) F_std(STD_Yr_Reverse_F(y))=0.0;
    t_base=styr+(y-styr)*nseas-1;
    
    if(y>styr)
    {
  //  SS_Label_Info_24.1.1 #Update the time varying biology factors if necessary
      if(time_vary_MG(y,0)>0 || save_for_report>0) get_MGsetup();
      if(time_vary_MG(y,2)>0)  
        {
          ALK_subseas_update=1;  // indicate that all ALKs will need re-estimation
          if(Grow_type!=2)
          {get_growth2();}
          else
          {get_growth2_Richards();}
        }
      if(time_vary_MG(y,1)>0) get_natmort();
      if(time_vary_MG(y,3)>0) get_wtlen();
      if(time_vary_MG(y,4)>0) get_recr_distribution();
      if(time_vary_MG(y,5)>0) get_migration();
      if(time_vary_MG(y,7)>0)  
      {
        get_catch_mult(y, catch_mult_pointer);
      }

      if(save_for_report>0)
      {
        if(time_vary_MG(y,1)>0 || time_vary_MG(y,2)>0 || time_vary_MG(y,3)>0)
        {
          get_saveGparm();
        }
      }
  //  SS_Label_Info_24.1.2  #Call selectivity, which does its own internal check for time-varying changes
      get_selectivity();
    }
  //  SS_Label_Info_24.2  #Loop the seasons
    for (s=1;s<=nseas;s++)
    {
      if (docheckup==1) echoinput<<endl<<"************************************"<<endl<<" year, seas "<<y<<" "<<s<<endl;
      t = t_base+s;
  //  SS_Label_Info_24.2.1 #Update the age-length key and the fishery selectivity for this season
      if(time_vary_MG(y,2)>0 || time_vary_MG(y,3)>0 || save_for_report==1 || WTage_rd>0)
      {
        subseas=1;  //  begin season  note that ALK_idx re-calculated inside get_growth3
        ALK_idx=(s-1)*N_subseas+subseas;  //  redundant with calc inside get_growth3 ????
        get_growth3(s, subseas);  
        Make_AgeLength_Key(s, subseas);
        
        subseas=mid_subseas;
        ALK_idx=(s-1)*N_subseas+subseas;
        get_growth3(s, subseas);
        Make_AgeLength_Key(s, subseas);  //  for midseason
//  SPAWN-RECR:   call Make_Fecundity in time series
        if(s==spawn_seas)
        {
          if(spawn_subseas!=1 && spawn_subseas!=mid_subseas)
          {
            subseas=spawn_subseas;
            ALK_idx=(s-1)*N_subseas+subseas;
            get_growth3(s, subseas);
            Make_AgeLength_Key(s, subseas);  //  spawn subseas
          }
          Make_Fecundity();
        }
      }
      Save_Wt_Age(t)=Wt_Age_beg(s);

      if(y>styr)    // because styr is done as part of initial conditions
      {
        for (g=1;g<=gmorph;g++)
        if(use_morph(g)>0)
        {Make_FishSelex();}
      }

      if(s==1)  //  calc some Smry_Table quantities that could be needed for exploitation rate calculations, but recalc these in the time_series report section
      {
        Smry_Table(y,2)=0.0;
        Smry_Table(y,3)=0.0;
        for (g=1;g<=gmorph;g++)
        if(use_morph(g)>0)
        {
        for (p=1;p<=pop;p++)
        {
          Smry_Table(y,2)+=natage(t,p,g)(Smry_Age,nages)*Save_Wt_Age(t,g)(Smry_Age,nages);
          Smry_Table(y,3)+=sum(natage(t,p,g)(Smry_Age,nages));   //sums to accumulate across platoons and settlements
        }
        }
      }

  //  SS_Label_Info_24.2.2 #Compute spawning biomass if this is spawning season so recruits could occur later this season
//  SPAWN-RECR:   calc SPB in time series if spawning is at beginning of the season
      if(s==spawn_seas && spawn_time_seas<0.0001)    //  compute spawning biomass if spawning at beginning of season so recruits could occur later this season
      {
        SPB_pop_gp(y).initialize();
        for (p=1;p<=pop;p++)
        {
          for (g=1;g<=gmorph;g++)
          if(sx(g)==1 && use_morph(g)>0)     //  female
          {
            SPB_pop_gp(y,p,GP4(g)) += fec(g)*natage(t,p,g);   // accumulates SSB by area and by growthpattern
            SPB_B_yr(y) += make_mature_bio(GP4(g))*natage(t,p,g);
            SPB_N_yr(y) += make_mature_numbers(GP4(g))*natage(t,p,g);
          }
        }
        SPB_current=sum(SPB_pop_gp(y));
        SPB_yr(y)=SPB_current;
        if(Hermaphro_Option>0)  // get male biomass
        {
          MaleSPB(y).initialize();
          for (p=1;p<=pop;p++)
          {
            for (g=1;g<=gmorph;g++)
            if(sx(g)==2 && use_morph(g)>0)     //  male; all assumed to be mature
            {
              MaleSPB(y,p,GP4(g)) += Save_Wt_Age(t,g)*natage(t,p,g);   // accumulates SSB by area and by growthpattern
            }
          }
          if(Hermaphro_maleSPB==1) // add MaleSPB to female SSB
          {
            SPB_current+=sum(MaleSPB(y));
            SPB_yr(y)=SPB_current;
          }
        }

  //  SS_Label_Info_24.2.3 #Get the total recruitment produced by this spawning biomass
//  SPAWN-RECR:   calc recruitment in time series; need to make this area-specific
        Recruits=Spawn_Recr(SPB_virgin,Recr_virgin,SPB_current);  // calls to function Spawn_Recr
// distribute Recruitment of age 0 fish among the current and future settlements; and among areas and morphs
            //  use t offset for each birth event:  Settlement_offset(settle)
            //  so the total number of Recruits will be relative to their numbers at the time of the set of settlement_events.
            //  so need the integer elapsed time (in season count) stored in Birth_offset()
            //  and need the real elapsed time (in fraction of a year) from the beginning of the season to settlement
            //  use NatM to calculate the virtual numbers that would have existed at the beginning of the season of the settlement
            //  need to use natM(t) because natM(t+offset) is not yet known
            //  also need to store the integer age at settlement
  //  SS_Label_Info_24.2.4 #Distribute Recruitment of age 0 fish among the pops and gmorphs
          for (g=1;g<=gmorph;g++)
          if(use_morph(g)>0)
          {
            settle=settle_g(g);
            for (p=1;p<=pop;p++)
            { 
              if(y==styr) natage(t+Settle_seas_offset(settle),p,g,Settle_age(settle))=0.0;  //  to negate the additive code 
              natage(t+Settle_seas_offset(settle),p,g,Settle_age(settle)) += Recruits*recr_dist(GP(g),settle,p)*platoon_distr(GP2(g))*
               mfexp(natM(s,GP3(g),Settle_age(settle))*Settle_timing_seas(settle));
            }
          }
      }

      else
      {
        //  spawning biomass and total recruits will be calculated later so they can use Z
      }

  //  SS_Label_Info_24.3 #Loop the areas
      for (p=1;p<=pop;p++)
      {

        for (g=1;g<=gmorph;g++)
        if(use_morph(g)>0)
        {
  //  SS_Label_Info_24.3.1 #Get middle of season numbers-at-age from M only;
          Nmid(g) = elem_prod(natage(t,p,g),surv1(s,GP3(g)));      //  get numbers-at-age(g,a) surviving to middle of time period
          if(docheckup==1) echoinput<<p<<" "<<g<<" "<<GP3(g)<<" area & morph "<<endl<<"N-at-age "<<natage(t,p,g)(0,min(6,nages))<<endl
           <<"survival "<<surv1(s,GP3(g))(0,min(6,nages))<<endl;
          if(save_for_report==1)
          {
  //  SS_Label_Info_24.3.2 #Store some beginning of season quantities
            Save_PopLen(t,p,g)=0.0;
            Save_PopLen(t,p+pop,g)=0.0;  // later put midseason here
            Save_PopWt(t,p,g)=0.0;
            Save_PopWt(t,p+pop,g)=0.0;  // later put midseason here
            Save_PopAge(t,p,g)=0.0;
            Save_PopAge(t,p+pop,g)=0.0;  // later put midseason here
            for (a=0;a<=nages;a++)
            {
              Save_PopLen(t,p,g)+=value(natage(t,p,g,a))*value(ALK(s,g,a));
              Save_PopWt(t,p,g)+=value(natage(t,p,g,a))*value(elem_prod(ALK(s,g,a),wt_len(s,GP(g))));
              Save_PopAge(t,p,g,a)=value(natage(t,p,g,a));
            } // close age loop
          }
//      echoinput<<y<<" "<<s<<" "<<g<<" nmid for catch "<<Nmid(g)<<endl;
        }

  //  SS_Label_Info_24.3.3 #Do fishing mortality using switch(F_method)
        catage_tot.initialize();

        if(catch_seas_area(t,p,0)==1 && fishery_on_off==1)
        {
          switch (F_Method_use)
          {
            case 1:          // F_Method is Pope's approximation
            {
  //  SS_Label_Info_24.3.3.1 #Use F_Method=1 for Pope's approximation
  //  SS_Label_Info_24.3.3.1.1 #loop over fleets
              for (f=1;f<=Nfleet;f++)
              if (catch_seas_area(t,p,f)==1)
              {
                dvar_matrix catage_w=catage(t,f);      // do shallow copy

  //  SS_Label_Info_24.3.3.1.2 #loop over platoons and calculate the vulnerable biomass for each fleet
                vbio.initialize();
                for (g=1;g<=gmorph;g++)
                if(use_morph(g)>0)
                {
                  // use sel_l to get total catch and use sel_l_r to get retained vbio
                  // note that vbio in numbers can be used for both survey abund and fishery available "biomass"
                  // vbio is for retained catch only;  harvest rate = retainedcatch/vbio;
                  // then harvestrate*catage_w = total kill by this fishery for this morph

                  if(catchunits(f)==1)
                  { vbio+=Nmid(g)*sel_al_2(s,g,f);}    // retained catch bio
                  else
                  { vbio+=Nmid(g)*sel_al_4(s,g,f);}  // retained catch numbers

                }  //close gmorph loop
                if(docheckup==1) echoinput<<"fleet vbio obs_catch catch_mult vbio*catchmult"<<f<<" "<<vbio<<" "<<catch_ret_obs(f,t)<<" "<<catch_mult(y,f)<<" "<<catch_mult(y,f)*vbio<<endl;
  //  SS_Label_Info_24.3.3.1.3 #Calculate harvest rate for each fleet from catch/vulnerable biomass
                crashtemp1=0.;
                crashtemp=max_harvest_rate-catch_ret_obs(f,t)/(catch_mult(y,f)*vbio+NilNumbers);
                crashtemp1=posfun(crashtemp,0.000001,CrashPen);
                harvest_rate=max_harvest_rate-crashtemp1;
                if(crashtemp<0.&&rundetail>=2) {cout<<y<<" "<<f<<" crash vbio*catchmult "<<catch_ret_obs(f,t)/(catch_mult(y,f)*(vbio+NilNumbers))<<" "<<crashtemp<<
                 " "<<crashtemp1<<" "<<CrashPen<<" "<<harvest_rate<<endl;}
                Hrate(f,t) = harvest_rate;

  //  SS_Label_Info_24.3.3.1.4 #Store various catch quantities in catch_fleet
                for (g=1;g<=gmorph;g++)
                if(use_morph(g)>0)
                {
                  catage_w(g)=harvest_rate*elem_prod(Nmid(g),deadfish(s,g,f));     // total kill numbers at age
                  if(docheckup==1) echoinput<<"killrate "<<deadfish(s,g,f)(0,min(6,nages))<<endl;
                  catage_tot(g) += catage_w(g); //catch at age for all fleets
                  catch_fleet(t,f,2)+=Hrate(f,t)*Nmid(g)*deadfish_B(s,g,f);      // total fishery kill in biomass
                  catch_fleet(t,f,5)+=Hrate(f,t)*Nmid(g)*deadfish(s,g,f);     // total fishery kill in numbers
                  catch_fleet(t,f,1)+=Hrate(f,t)*Nmid(g)*sel_al_1(s,g,f);      //  total fishery encounter in biomass
                  catch_fleet(t,f,3)+=Hrate(f,t)*Nmid(g)*sel_al_2(s,g,f);      // retained fishery kill in biomass
                  catch_fleet(t,f,4)+=Hrate(f,t)*Nmid(g)*sel_al_3(s,g,f);      // encountered numbers
                  catch_fleet(t,f,6)+=Hrate(f,t)*Nmid(g)*sel_al_4(s,g,f);      // retained fishery kill in numbers
                }  // end g loop
              }  // close fishery

  //  SS_Label_Info_24.3.3.1.5 #Check for catch_total across fleets being greater than population numbers
              for (g=1;g<=gmorph;g++)
              if(use_morph(g)>0)
              {
                for (a=0;a<=nages;a++)    //  check for negative abundance, starting at age 1
                {
                  if(natage(t,p,g,a)>0.0)
                  {
                  crashtemp=max_harvest_rate-catage_tot(g,a)/(Nmid(g,a)+0.0000001);
                  crashtemp1=posfun(crashtemp,0.000001,CrashPen);
                  if(crashtemp<0.&&rundetail>=2) {cout<<" crash age "<<catage_tot(g,a)/(Nmid(g,a)+0.0000001)<<" "<<crashtemp<<
                    " "<<crashtemp1<<" "<<CrashPen<<" "<<(max_harvest_rate-crashtemp1)*Nmid(g,a)<<endl; }
                  if(crashtemp<0.&&docheckup==1) {echoinput<<" crash age "<<catage_tot(g,a)/(Nmid(g,a)+0.0000001)<<" "<<crashtemp<<
                    " "<<crashtemp1<<" "<<CrashPen<<" "<<(max_harvest_rate-crashtemp1)*Nmid(g,a)<<endl; }
                  catage_tot(g,a)=(max_harvest_rate-crashtemp1)*Nmid(g,a);

                  temp = natage(t,p,g,a)*surv2(s,GP3(g),a) -catage_tot(g,a)*surv1(s,GP3(g),a);
                  Z_rate(t,p,g,a)=-log(temp/natage(t,p,g,a))/seasdur(s);
                  }
                  else
                  {
                    Z_rate(t,p,g,a)=-log(surv2(s,GP3(g),a))/seasdur(s);
                  }
                }
                if(docheckup==1) echoinput<<y<<" "<<s<<"total catch-at-age for morph "<<g<<" "<<catage_tot(g)(0,min(6,nages))<<" Z: "<<Z_rate(t,p,g)(0,min(6,nages))<<endl;
              }
              break;
            }   //  end Pope's approx

  //  SS_Label_Info_24.3.3.2 #Use a parameter for continuoous F
            case 2:          // continuous F_method
            {
  //  SS_Label_Info_24.3.3.2.1 #For each platoon, loop fleets to calculate Z = M+sum(F)
              for (g=1;g<=gmorph;g++)
              if(use_morph(g)>0)
              {
                Z_rate(t,p,g)=natM(s,GP3(g));
                for (f=1;f<=Nfleet;f++)
                if (catch_seas_area(t,p,f)==1)
                {
                  Z_rate(t,p,g)+=deadfish(s,g,f)*Hrate(f,t);
                }
                Zrate2(p,g)=elem_div( (1.-mfexp(-seasdur(s)*Z_rate(t,p,g))), Z_rate(t,p,g));
              }

  //  SS_Label_Info_24.3.3.2.2 #For each fleet, loop platoons and accumulate catch
              for (f=1;f<=Nfleet;f++)
              if (catch_seas_area(t,p,f)==1)
              {
                for (g=1;g<=gmorph;g++)
                if(use_morph(g)>0)
                {
                  catch_fleet(t,f,1)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_1(s,g,f))*Zrate2(p,g);
                  catch_fleet(t,f,2)+=Hrate(f,t)*elem_prod(natage(t,p,g),deadfish_B(s,g,f))*Zrate2(p,g);
                  catch_fleet(t,f,3)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_2(s,g,f))*Zrate2(p,g); // retained bio
                  catch_fleet(t,f,4)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_3(s,g,f))*Zrate2(p,g);
                  catch_fleet(t,f,5)+=Hrate(f,t)*elem_prod(natage(t,p,g),deadfish(s,g,f))*Zrate2(p,g);
                  catch_fleet(t,f,6)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_4(s,g,f))*Zrate2(p,g);  // retained numbers
                  catage(t,f,g)=Hrate(f,t)*elem_prod(elem_prod(natage(t,p,g),deadfish(s,g,f)),Zrate2(p,g));
                }  //close gmorph loop
              }  // close fishery
              break;
            }   //  end continuous F method

  //  SS_Label_Info_24.3.3.3 #use the hybrid F method
            case 3:          // hybrid F_method
            {
  //  SS_Label_Info_24.3.3.3.1 #Start by doing a Pope's approximation
              for (f=1;f<=Nfleet;f++)
              if(fleet_type(f)==1) // do exact catch for this fleet; skipping adjustment for bycatch fleets
              {
                if (catch_seas_area(t,p,f)==1)  
                {
                  vbio.initialize();
                  for (g=1;g<=gmorph;g++)
                  if(use_morph(g)>0)
                  {
                    if(catchunits(f)==1)
                      {vbio+=Nmid(g)*sel_al_2(s,g,f);}    // retained catch bio
                    else
                      {vbio+=Nmid(g)*sel_al_4(s,g,f);}  // retained catch numbers
                  }  //close gmorph loop
    //  SS_Label_Info_24.3.3.3.2 #Apply constraint so that no fleet's initial calculation of harvest rate would exceed 95%
                  temp = catch_ret_obs(f,t)/(vbio+0.1*catch_ret_obs(f,t));  //  Pope's rate  robust
                  join1=1./(1.+mfexp(30.*(temp-0.95)));  // steep logistic joiner at harvest rate of 0.95
                  temp1=join1*temp + (1.-join1)*0.95;
    //  SS_Label_Info_24.3.3.3.3 #Convert the harvest rate to a starting value for F
                  Hrate(f,t)=-log(1.-temp1)/seasdur(s);  // initial estimate of F (even though labelled as Hrate)
                  //  done with starting values from Pope's approximation
                }
                else
                {
                  // Hrate(f,t) previously set to zero or set to a parameter value
                }
              }
  //  SS_Label_Info_24.3.3.3.4 #Do a specified number of loops to tune up these F values to more closely match the observed catch
            	for (int tune_F=1;tune_F<=F_Tune;tune_F++)
              {
  //  SS_Label_Info_24.3.3.3.5 #add F+M to get Z 
                for (g=1;g<=gmorph;g++)
                if(use_morph(g)>0)
                {
                  Z_rate(t,p,g)=natM(s,GP3(g));
                  for (f=1;f<=Nfleet;f++)       //loop over fishing fleets to get Z
                  if (catch_seas_area(t,p,f)!=0)
                  {
                    Z_rate(t,p,g)+=deadfish(s,g,f)*Hrate(f,t);
                  }
                  Zrate2(p,g)=elem_div( (1.-mfexp(-seasdur(s)*Z_rate(t,p,g))), Z_rate(t,p,g));
                }

  //  SS_Label_Info_24.3.3.3.6 #Now calc adjustment to Z based on changes to be made to Hrate
                if(tune_F<F_Tune)
                {
                  //  now calc adjustment to Z based on changes to be made to Hrate
                  interim_tot_catch=0.0;   // this is the expected total catch that would occur with the current Hrates and Z
                  for (f=1;f<=Nfleet;f++)
                  if(fleet_type(f)==1)  //  skips bycatch fleets
                  {
                    if (catch_seas_area(t,p,f)==1)
                    {
                      for (g=1;g<=gmorph;g++)
                      if(use_morph(g)>0)
                      {
                        if(catchunits(f)==1)
                        {
                          interim_tot_catch+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_2(s,g,f))*Zrate2(p,g);  // biomass basis
                        }
                        else
                        {
                          interim_tot_catch+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_4(s,g,f))*Zrate2(p,g);  //  numbers basis
                        }
                      }  //close gmorph loop
                    }  // close fishery
                  }
                  Z_adjuster = totcatch_byarea(t,p)/(interim_tot_catch+0.0001);   // but this totcatch_by_area needs to exclude fisheries with F from param
                  for (g=1;g<=gmorph;g++)
                  if(use_morph(g)>0)
                  {
                    Z_rate(t,p,g)=natM(s,GP3(g)) + Z_adjuster*(Z_rate(t,p,g)-natM(s,GP3(g)));  // need to modify to only do the exact catches
                    Zrate2(p,g)=elem_div( (1.-mfexp(-seasdur(s)*Z_rate(t,p,g))), Z_rate(t,p,g));
                  }
                  for (f=1;f<=Nfleet;f++)       //loop over fishing  fleets with input catch
                  if(fleet_type(f)==1)
                  {
                    if(catch_seas_area(t,p,f)==1)
                    {
                      vbio=0.;  // now use this to calc the selected vulnerable biomass (numbers) to each fishery with the adjusted Zrate2
                      //  since catch = N * F*sel * (1-e(-Z))/Z 
                      //  so F = catch / (N*sel * (1-e(-Z)) /Z )
                      for (g=1;g<=gmorph;g++)
                      if(use_morph(g)>0)
                      {
                        if(catchunits(f)==1)
                        {
                          vbio+=elem_prod(natage(t,p,g),sel_al_2(s,g,f)) *Zrate2(p,g);
                        }
                        else
                        {
                          vbio+=elem_prod(natage(t,p,g),sel_al_4(s,g,f)) *Zrate2(p,g);
                        }
                      }  //close gmorph loop
                      temp=catch_ret_obs(f,t)/(catch_mult(y,f)*vbio+0.0001);  //  prototype new F
                      join1=1./(1.+mfexp(30.*(temp-0.95*max_harvest_rate)));
                      Hrate(f,t)=join1*temp + (1.-join1)*max_harvest_rate;  //  new F value for this fleet
                    }  // close fishery
                  }
                }
                else
                {
  //  SS_Label_Info_24.3.3.3.7 #Final tuning loop; loop over fleets to apply the iterated F
                for (f=1;f<=Nfleet;f++) 
                if (catch_seas_area(t,p,f)==1)
                {
                  for (g=1;g<=gmorph;g++)
                  if(use_morph(g)>0)
                  {
                    catch_fleet(t,f,1)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_1(s,g,f))*Zrate2(p,g);
                    catch_fleet(t,f,2)+=Hrate(f,t)*elem_prod(natage(t,p,g),deadfish_B(s,g,f))*Zrate2(p,g);
                    catch_fleet(t,f,3)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_2(s,g,f))*Zrate2(p,g);
                    catch_fleet(t,f,4)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_3(s,g,f))*Zrate2(p,g);
                    catch_fleet(t,f,5)+=Hrate(f,t)*elem_prod(natage(t,p,g),deadfish(s,g,f))*Zrate2(p,g);
                    catch_fleet(t,f,6)+=Hrate(f,t)*elem_prod(natage(t,p,g),sel_al_4(s,g,f))*Zrate2(p,g);
                    catage(t,f,g)=Hrate(f,t)*elem_prod(elem_prod(natage(t,p,g),deadfish(s,g,f)),Zrate2(p,g));
                  }  //close gmorph loop
                }  // close fishery
                }
              }
              break;
            }   //  end hybrid F_Method
          }  // end F_Method switch
        }  //  end have some catch in this seas x area
        else
        {
  //  SS_Label_Info_24.3.3.4 #No catch or fishery turned off, so set Z=M
          for (g=1;g<=gmorph;g++)
          if(use_morph(g)>0)
          {Z_rate(t,p,g)=natM(s,GP3(g));}
        }
   } //close area loop

  //  SS_Label_Info_24.3.4 #Compute spawning biomass if occurs after start of current season
//  SPAWN-RECR:   calc spawn biomass in time series if after beginning of the season
      if(s==spawn_seas && spawn_time_seas>=0.0001)    //  compute spawning biomass
      {
        SPB_pop_gp(y).initialize();
        for (p=1;p<=pop;p++)
        {
          for (g=1;g<=gmorph;g++)
          if(sx(g)==1 && use_morph(g)>0)     //  female
          {
            SPB_pop_gp(y,p,GP4(g)) += fec(g)*elem_prod(natage(t,p,g),mfexp(-Z_rate(t,p,g)*spawn_time_seas));   // accumulates SSB by area and by growthpattern
            SPB_B_yr(y) += make_mature_bio(GP4(g))*elem_prod(natage(t,p,g),mfexp(-Z_rate(t,p,g)*spawn_time_seas));
            SPB_N_yr(y) += make_mature_numbers(GP4(g))*elem_prod(natage(t,p,g),mfexp(-Z_rate(t,p,g)*spawn_time_seas));
          }
        }
        SPB_current=sum(SPB_pop_gp(y));
        SPB_yr(y)=SPB_current;

        if(Hermaphro_Option>0)  // get male biomass
        {
          MaleSPB(y).initialize();
          for (p=1;p<=pop;p++)
          {
            for (g=1;g<=gmorph;g++)
            if(sx(g)==2 && use_morph(g)>0)     //  male; all assumed to be mature
            {
              MaleSPB(y,p,GP4(g)) += Save_Wt_Age(t,g)*elem_prod(natage(t,p,g),mfexp(-Z_rate(t,p,g)*spawn_time_seas));   // accumulates SSB by area and by growthpattern
            }
          }
          if(Hermaphro_maleSPB==1) // add MaleSPB to female SSB
          {
            SPB_current+=sum(MaleSPB(y));
            SPB_yr(y)=SPB_current;
          }
        }
  //  SS_Label_Info_24.3.4.1 #Get recruitment from this spawning biomass
//  SPAWN-RECR:   calc recruitment in time series; need to make this area-specififc
        Recruits=Spawn_Recr(SPB_virgin,Recr_virgin,SPB_current);  // calls to function Spawn_Recr
// distribute Recruitment of age 0 fish among the current and future settlements; and among areas and morphs
//  note that because SPB_current is calculated at end of season to take into account Z,
//  this means that recruitment cannot occur until a subsequent season
//  SPAWN-RECR:   distribute recruits among areas, settlements, morphs
          for (g=1;g<=gmorph;g++)
          if(use_morph(g)>0)
          {
            settle=settle_g(g);
            for (p=1;p<=pop;p++)
            { 
              if(y==styr) natage(t+Settle_seas_offset(settle),p,g,Settle_age(settle))=0.0;  //  to negate the additive code 
                
              natage(t+Settle_seas_offset(settle),p,g,Settle_age(settle)) += Recruits*recr_dist(GP(g),settle,p)*platoon_distr(GP2(g))*
               mfexp(natM(s,GP3(g),Settle_age(settle))*Settle_timing_seas(settle));
          if(docheckup==1) echoinput<<p<<" "<<g<<" "<<GP3(g)<<" area & morph "<<endl<<"N-at-age after recruits "<<natage(t,p,g)(0,min(6,nages))<<endl
           <<"survival "<<surv1(s,GP3(g))(0,min(6,nages))<<endl;
            }
          }
      }

  //  SS_Label_Info_24.6 #Survival to next season
  for (p=1;p<=pop;p++)
  {
        if(s==nseas) {k=1;} else {k=0;}   //      advance age or not
        for (g=1;g<=gmorph;g++)
        if(use_morph(g)>0)
        {
            settle=settle_g(g);

 /*
          if(F_Method==1)  // pope's
          {
              if(s<nseas) natage(t+1,p,g,0) = natage(t,p,g,0)*surv2(s,GP3(g),0) -catage_tot(g,0)*surv1(s,GP3(g),0);  // advance age zero within year

              for (a=0;a<nages;a++)
              {
                natage(t+1,p,g,a) = natage(t,p,g,a-k)*surv2(s,GP3(g),a-k) -catage_tot(g,a-k)*surv1(s,GP3(g),a-k);
//                Z_rate(t,p,g,a)=-log(natage(t+1,p,g,a)/natage(t,p,g,a-k))/seasdur(s);
              }
              natage(t+1,p,g,nages) = natage(t,p,g,nages)*surv2(s,GP3(g),nages) - catage_tot(g,nages)*surv1(s,GP3(g),nages);   // plus group
//              Z_rate(t,p,g,nages)=-log( natage(t+1,p,g,nages)/natage(t,p,g,nages))/seasdur(s);
              if(s==nseas) natage(t+1,p,g,nages) += natage(t,p,g,nages-1)*surv2(s,GP3(g),nages-1) - catage_tot(g,nages-1)*surv1(s,GP3(g),nages-1);
              if(save_for_report==1)
              {
                j=p+pop;
                for (a=0;a<=nages;a++)
                {
                  Save_PopLen(t,j,g)+=value(Nmid(g,a)-0.5*catage_tot(g,a))*value(ALK(ALK_idx,g,a));
                  Save_PopWt(t,j,g)+= value(Nmid(g,a)-0.5*catage_tot(g,a))*value(elem_prod(ALK(ALK_idx,g,a),wt_len(s,sx(g))));
                  Save_PopAge(t,j,g,a)=value(Nmid(g,a)-0.5*catage_tot(g,a));
                } // close age loop
              }
          }
          else   // continuous F
 */
          {
            if(s<nseas && Settle_seas(settle)<=s) natage(t+1,p,g,0) = natage(t,p,g,0)*mfexp(-Z_rate(t,p,g,0)*seasdur(s));  // advance age zero within year
            for (a=1;a<nages;a++) {natage(t+1,p,g,a) = natage(t,p,g,a-k)*mfexp(-Z_rate(t,p,g,a-k)*seasdur(s));}
            natage(t+1,p,g,nages) = natage(t,p,g,nages)*mfexp(-Z_rate(t,p,g,nages)*seasdur(s));   // plus group
            if(s==nseas) natage(t+1,p,g,nages) += natage(t,p,g,nages-1)*mfexp(-Z_rate(t,p,g,nages-1)*seasdur(s));
              if(save_for_report==1)
              {
                j=p+pop;
                for (a=0;a<=nages;a++)
                {
                  Save_PopLen(t,j,g)+=value(natage(t,p,g,a)*mfexp(-Z_rate(t,p,g,a)*0.5*seasdur(s)))*value(ALK(ALK_idx,g,a));
                  Save_PopWt(t,j,g)+= value(natage(t,p,g,a)*mfexp(-Z_rate(t,p,g,a)*0.5*seasdur(s)))*value(elem_prod(ALK(ALK_idx,g,a),wt_len(s,GP(g))));
                  Save_PopAge(t,j,g,a)=value(natage(t,p,g,a)*mfexp(-Z_rate(t,p,g,a)*0.5*seasdur(s)));
                } // close age loop
              }
          }
          if(docheckup==1)
          {
            echoinput<<g<<" natM:   "<<natM(s,GP3(g))(0,min(6,nages))<<endl;
            echoinput<<g<<" Z:      "<<Z_rate(t,p,g)(0,min(6,nages))<<endl;
            echoinput<<g<<" N_surv: "<<natage(t+1,p,g)(0,min(6,nages))<<endl;
          }
        } // close gmorph loop
  }

  //  SS_Label_Info_24.7  #call to Get_expected_values
    Get_expected_values();
  //  SS_Label_Info_24.8  #hermaphroditism
      if(Hermaphro_Option>0)
      {
        if(Hermaphro_seas==-1 || Hermaphro_seas==s)
        {
          k=gmorph/2;  //  because first half of the "g" are females
          for (p=1;p<=pop;p++)  //   area
          for (g=1;g<=k;g++)  //  loop females
          if(use_morph(g)>0)
          {
            for (a=1;a<nages;a++)
            {
              natage(t+1,p,g+k,a) += natage(t+1,p,g,a)*Hermaphro_val(GP4(g),a-1); // increment males
              natage(t+1,p,g,a) *= (1.-Hermaphro_val(GP4(g),a-1)); // decrement females
            }
          }
        }
      }

  //  SS_Label_Info_24.9  #migration
//do migration between populations, for each gmorph and age  PROBLEM  need new container so future recruits not wiped out!
      if(do_migration>0)  // movement between areas in time series
      {
        natage_temp=natage(t+1);
        natage(t+1)=0.0;
        for (p=1;p<=pop;p++)  //   source population
        for (p2=1;p2<=pop;p2++)  //  destination population
        for (g=1;g<=gmorph;g++)
        if(use_morph(g)>0)
        {
          k=move_pattern(s,GP4(g),p,p2);
          if(k>0) natage(t+1,p2,g) += elem_prod(natage_temp(p,g),migrrate(y,k));}
      }  //  end migration

  //  SS_Label_Info_24.10  #save selectivity*Hrate for tag-recapture
      if(Do_TG>0 && t>=TG_timestart)
      {
        for (g=1;g<=gmorph;g++)
        for (f=1;f<=Nfleet;f++)
        {
          Sel_for_tag(t,g,f) = sel_al_4(s,g,f)*Hrate(f,t);
        }
      }

  //  SS_Label_Info_24.11  #calc annual F quantities
      if( fishery_on_off==1 && ((save_for_report>0) || ((sd_phase() || mceval_phase()) && (initial_params::mc_phase==0)|| (F_ballpark_yr>=styr))) )
      {
        for (f=1;f<=Nfleet;f++)
        {
          for (k=1;k<=6;k++)
          {
            annual_catch(y,k)+=catch_fleet(t,f,k);
          }
          if(F_Method==1)
          {
            annual_F(y,1)+=Hrate(f,t);
          }
          else
          {
            annual_F(y,1)+=Hrate(f,t)*seasdur(s);
          }
        }
        
        if(s==nseas)
        {
  //  sum across p and g the number of survivors to end of the year
  //  also project from the initial numbers and M, the number of survivors without F
  //  then F = ln(n+1/n)(M+F) - ln(n+1/n)(M only), but ln(n) cancels out, so only need the ln of the ratio of the two ending quantities
          temp=0.0;
          temp1=0.0;
          temp2=0.0;
          for (g=1;g<=gmorph;g++)
          if(use_morph(g)>0)
          {
            for (p=1;p<=pop;p++)
            {
              for (a=F_reporting_ages(1);a<=F_reporting_ages(2);a++)   //  should not let a go higher than nages-2 because of accumulator
              {
                temp1+=natage(t+1,p,g,a+1);
                if(nseas==1)
                {
                  temp2+=natage(t,p,g,a)*mfexp(-seasdur(s)*natM(s,GP3(g),a));
                }
                else
                {
                  temp3=natage(t-nseas+1,p,g,a);  //  numbers at begin of year
                  for (j=1;j<=nseas;j++) {temp3*=mfexp(-seasdur(j)*natM(j,GP3(g),a));}
                  temp2+=temp3;
                }
              }
            }
          }
          annual_F(y,2) = log(temp2)-log(temp1);
        
          if(STD_Yr_Reverse_F(y)>0)  //  save selected std quantity
          {
            if(F_reporting<=1)
            {
              F_std(STD_Yr_Reverse_F(y))=annual_catch(y,2)/Smry_Table(y,2);  // dead catch biomass/summary biomass
                                                                             //  does not exactly correspond to F, which is for total catch
            }
            else if(F_reporting==2)
            {
              F_std(STD_Yr_Reverse_F(y))=annual_catch(y,5)/Smry_Table(y,3);  // dead catch numbers/summary numbers
            }
            else if(F_reporting==3)
            {
              F_std(STD_Yr_Reverse_F(y))=annual_F(y,1);
            }
            else if(F_reporting==4)
            {
              F_std(STD_Yr_Reverse_F(y))=annual_F(y,2);
            }
          }
        }  //  end s==nseas
      }
    } //close season loop
  //  SS_Label_Info_24.12 #End loop of seasons


  //  SS_Label_Info_24.13 #Use current F intensity to calculate the equilibrium SPR for this year
    if( (save_for_report>0) || ((sd_phase() || mceval_phase()) && (initial_params::mc_phase==0)) )
    {
      eq_yr=y; equ_Recr=Recr_virgin; bio_yr=y;
      dvariable SPR_unf;
      Fishon=0;
      Do_Equil_Calc();                      //  call function to do equilibrium calculation with current year's biology
      SPR_unf=SPB_equil;
      Smry_Table(y,11)=SPR_unf;
      Smry_Table(y,13)=GenTime;
      Fishon=1;
      Do_Equil_Calc();                      //  call function to do equilibrium calculation with current year's biology and F
      if(STD_Yr_Reverse_Ofish(y)>0)
      {
        SPR_std(STD_Yr_Reverse_Ofish(y))=SPB_equil/SPR_unf;
      }
      Smry_Table(y,9)=(totbio);
      Smry_Table(y,10)=(smrybio);
      Smry_Table(y,12)=(SPB_equil);
      Smry_Table(y,14)=(YPR_dead);
      for (g=1;g<=gmorph;g++)
      {
        Smry_Table(y,20+g)=(cumF(g));
        Smry_Table(y,20+gmorph+g)=(maxF(g));
      }
    }
  } //close year loop
  //  SS_Label_Info_24.14 #End loop of years

  if(Do_TG>0)
  {
  //  SS_Label_Info_24.15 #do tag mortality, movement and recapture
    dvariable TG_init_loss;
    dvariable TG_chron_loss;
    TG_recap_exp.initialize();
    for (TG=1;TG<=N_TG;TG++)
    {
      firstseas=int(TG_release(TG,4));  // release season
      t=int(TG_release(TG,5));  // release t index calculated in data section from year and season of release
      p=int(TG_release(TG,2));  // release area
      gg=int(TG_release(TG,6));  // gender (1=fem; 2=male; 0=both
      a1=int(TG_release(TG,7));  // age at release

      TG_alive.initialize();
      if(gg==0)
      {
        for (g=1;g<=gmorph;g++) {TG_alive(p,g) = natage(t,p,g,a1);}   //  gets both genders
      }
      else
      {
        for (g=1;g<=gmorph;g++)
        {
          if(sx(g)==gg) {TG_alive(p,g) = natage(t,p,g,a1);}  //  only does the selected gender
        }
      }
      TG_init_loss = mfexp(TG_parm(TG))/(1.+mfexp(TG_parm(TG)));
      TG_chron_loss = mfexp(TG_parm(TG+N_TG))/(1.+mfexp(TG_parm(TG+N_TG)));
      for (f=1;f<=Nfleet;f++)
      {
        k=3*N_TG+f;
        TG_report(f) = mfexp(TG_parm(k))/(1.0+mfexp(TG_parm(k)));
        TG_rep_decay(f) = TG_parm(k+Nfleet);
      }
      TG_alive /= sum(TG_alive);     // proportions across morphs at age a1 in release area p at time of release t
      TG_alive *= TG_release(TG,8);   //  number released as distributed across morphs
      TG_alive *= (1.-TG_init_loss);  // initial mortality
      if(save_for_report>0)
      {
        TG_save(TG,1)=value(TG_init_loss);
        TG_save(TG,2)=value(TG_chron_loss);
      }

      TG_t=0;
      for (y=TG_release(TG,3);y<=endyr;y++)
      {
        for (s=firstseas;s<=nseas;s++)
        {
          if(save_for_report>0 && TG_t<=TG_endtime(TG))
          {TG_save(TG,3+TG_t)=value(sum(TG_alive));} //  OK to do simple sum because only selected morphs are populated

          for (p=1;p<=pop;p++)
          {
            for (g=1;g<=gmorph;g++)
            if(TG_use_morph(TG,g)>0)
            {
              for (f=1;f<=Nfleet;f++)
              if (fleet_area(f)==p)
              {
// calculate recaptures by fleet
// NOTE:  Sel_for_tag(t,g,f,a1) = sel_al_4(s,g,f,a1)*Hrate(f,t)
                if(F_Method==1)
                {
                  TG_recap_exp(TG,TG_t,f)+=TG_alive(p,g)  // tags recaptured
                  *mfexp(-(natM(s,GP3(g),a1)+TG_chron_loss)*seasdur_half(s))
                  *Sel_for_tag(t,g,f,a1)
                  *TG_report(f)
                  *mfexp(TG_t*TG_rep_decay(f));
                }
                else   // use for method 2 and 3
                {
                  TG_recap_exp(TG,TG_t,f)+=TG_alive(p,g)
                  *Sel_for_tag(t,g,f,a1)/(Z_rate(t,p,g,a1)+TG_chron_loss)
                  *(1.-mfexp(-seasdur(s)*(Z_rate(t,p,g,a1)+TG_chron_loss)))
                  *TG_report(f)
                  *mfexp(TG_t*TG_rep_decay(f));
                }
  if(docheckup==1) echoinput<<" TG_"<<TG<<" y_"<<y<<" s_"<<s<<" area_"<<p<<" g_"<<g<<" GP3_"<<GP3(g)<<" f_"<<f<<" a1_"<<a1<<" Sel_"<<Sel_for_tag(t,g,f,a1)<<" TG_alive_"<<TG_alive(p,g)<<" TG_obs_"<<TG_recap_obs(TG,TG_t,f)<<" TG_exp_"<<TG_recap_exp(TG,TG_t,f)<<endl;
              }  // end fleet loop for recaptures

// calculate survival
              if(F_Method==1)
              {
                if(s==nseas) {k=1;} else {k=0;}   //      advance age or not
                if((a1+k)<=(nages-1)) {f=a1-1;} else {f=nages-2;}
                TG_alive(p,g)*=(natage(t+1,p,g,f+k)+1.0e-10)/(natage(t,p,g,f)+1.0e-10)*(1.-TG_chron_loss*seasdur(s));
              }
              else   //  use for method 2 and 3
              {
                TG_alive(p,g)*=mfexp(-seasdur(s)*(Z_rate(t,p,g,a1)+TG_chron_loss));
              }
            }  // end morph loop
          }  // end area loop

          if(Hermaphro_Option>0)
          {
            if(Hermaphro_seas==-1 || Hermaphro_seas==s)
            {
              k=gmorph/2;
              for (p=1;p<=pop;p++)  //   area
              for (g=1;g<=k;g++)  //  loop females
              if(use_morph(g)>0)
              {
                TG_alive(p,g+k) += TG_alive(p,g)*Hermaphro_val(GP4(g),a1); // increment males
                TG_alive(p,g) *= (1.-Hermaphro_val(GP4(g),a1)); // decrement females
              }
            }
          }

          if(do_migration>0)  //  movement between areas of tags
          {
            TG_alive_temp=TG_alive;
            TG_alive=0.0;
            for (g=1;g<=gmorph;g++)
            if(use_morph(g)>0)
            {
              for (p=1;p<=pop;p++)  //   source population
              for (p2=1;p2<=pop;p2++)  //  destination population
              {
                k=move_pattern(s,GP4(g),p,p2);
                if(k>0) TG_alive(p2,g) += TG_alive_temp(p,g)*migrrate(y,k,a1);
              }
            }
            if(docheckup==1) echoinput<<" Tag_alive after survival and movement "<<endl<<TG_alive<<endl;
          }
          t++;         //  increment seasonal time counter
          if(TG_t<TG_endtime(TG)) TG_t++;
          if(s==nseas && a1<nages) a1++;
        }  // end seasons
        firstseas=1;  // so start with season 1 in year following the tag release
      }  // end years
    }  //  end loop of tag groups
  }  // end having tag groups
  }  //  end time_series
  //  SS_Label_Info_24.16  # end of time series function

//********************************************************************
 /*  SS_Label_FUNCTION 30 Do_Equil_Calc */
FUNCTION void Do_Equil_Calc()
  {
  int t_base;
  int bio_t_base;
  int bio_t;
  dvariable N_mid;
  dvariable N_beg;
  dvariable Fishery_Survival;
  dvariable crashtemp;
  dvariable crashtemp1;
  dvar_matrix Survivors(1,pop,1,gmorph);
  dvar_matrix Survivors2(1,pop,1,gmorph);

   t_base=styr+(eq_yr-styr)*nseas-1;
   bio_t_base=styr+(bio_yr-styr)*nseas-1;
   GenTime.initialize(); Equ_penalty.initialize();
   cumF.initialize(); maxF.initialize();
   SPB_equil_pop_gp.initialize();
   if(Hermaphro_Option>0) MaleSPB_equil_pop_gp.initialize();
   equ_mat_bio=0.0;
   equ_mat_num=0.0;
   equ_catch_fleet.initialize();
   equ_numbers.initialize();
   equ_catage.initialize();
   equ_F_std=0.0;
   totbio=0.0;
   smrybio=0.0;
   smryage=0.0;
   smrynum=0.0;
// first seed the recruits; seems redundant
      for (g=1;g<=gmorph;g++)
      {
        if(use_morph(g)>0)
        {
          settle=settle_g(g);
          for (p=1;p<=pop;p++)
          { 
            equ_numbers(Settle_seas(settle),p,g,Settle_age(settle)) = equ_Recr*recr_dist(GP(g),settle,p)*platoon_distr(GP2(g))*
             mfexp(natM(Settle_seas(settle),GP3(g),Settle_age(settle))*Settle_timing_seas(settle));
          }
        }
      }

     for (a=0;a<=3*nages;a++)     // go to 3x nages to approximate the infinite tail, then add the infinite tail
     {
       if(a<=nages) {a1=a;} else {a1=nages;}    // because selex and biology max out at nages

       for (s=1;s<=nseas;s++)
       {
         t=t_base+s;
         bio_t=bio_t_base+s;

         for (g=1;g<=gmorph;g++)  //  need to loop g inside of a because of hermaphroditism
         if(use_morph(g)>0)
         {
           gg=sx(g);    // gender
           settle=settle_g(g);

           for (p=1;p<=pop;p++)
           {
             if(s==Settle_seas(settle) && a==Settle_age(settle))
              {
                equ_numbers(Settle_seas(settle),p,g,Settle_age(settle)) = equ_Recr*recr_dist(GP(g),settle,p)*platoon_distr(GP2(g))*
                mfexp(natM(Settle_seas(settle),GP3(g),Settle_age(settle))*Settle_timing_seas(settle));
              }

           if(equ_numbers(s,p,g,a)>0.0)  //  will only be zero if not yet settled
           {
             N_beg=equ_numbers(s,p,g,a);
             if(F_Method==1)   // Pope's approx
             {
                 N_mid = N_beg*surv1(s,GP3(g),a1);     // numbers at middle of season
                 Nsurvive=N_mid;                            // initial number of fishery survivors
                 if(Fishon==1)
                 {                       //  remove catch this round
                   // check to see if total harves would exceed max_harvest_rate
                   crashtemp=0.;  harvest_rate=1.0;
                   for (f=1;f<=Nfleet;f++)
                   if (fleet_area(f)==p && Hrate(f,t)>0.)
                   {
                     crashtemp+=Hrate(f,t)*deadfish(s,g,f,a1);
                   }

                   if(crashtemp>0.20)                  // only worry about this if the exploit rate is at all high
                   {
                     join1=1./(1.+mfexp(40.0*(crashtemp-max_harvest_rate)));  // steep joiner logistic curve at limit
                     upselex=1./(1.+mfexp(Equ_F_joiner*(crashtemp-0.2)));          //  value of a shallow logistic curve that goes through the limit
                     harvest_rate = join1 + (1.-join1)*upselex/(crashtemp);      // ratio by which all Hrates will be adjusted
                   }

                   for (f=1;f<=Nfleet;f++)
                   if (fleet_area(f)==p && Hrate(f,t)>0. && fleet_type(f)<=2)
                   {
                     temp=N_mid*Hrate(f,t)*harvest_rate;     // numbers that would be caught if fully selected
                     Nsurvive-=temp*deadfish(s,g,f,a1);       //  survival from fishery kill
                     equ_catch_fleet(2,s,f) += temp*deadfish_B(s,g,f,a1);
                     equ_catch_fleet(5,s,f) += temp*deadfish(s,g,f,a1);
                     equ_catch_fleet(3,s,f) += temp*sel_al_2(s,g,f,a1);      // retained fishery kill in biomass

                       equ_catch_fleet(1,s,f)+=temp*sel_al_1(s,g,f,a1);      //  total fishery encounter in biomass
                       equ_catch_fleet(4,s,f)+=temp*sel_al_3(s,g,f,a1);    // total fishery encounter in numbers
                       equ_catch_fleet(6,s,f)+=temp*sel_al_4(s,g,f,a1);      // retained fishery kill in numbers
                       equ_catage(s,f,g,a1)+=temp*deadfish(s,g,f,a1);      //  dead catch numbers per recruit  (later accumulate N in a1)
                   }
                 }   // end removing catch

                 Nsurvive *= surv1(s,GP3(g),a1);  // decay to end of season

                 if(a<=a1)
                 {
                   equ_Z(s,p,g,a1) = -(log((Nsurvive+1.0e-13)/(N_beg+1.0e-10)))/seasdur(s);
                   Fishery_Survival = equ_Z(s,p,g,a1)-natM(s,GP3(g),a1);
                   if(a>=Smry_Age)
                   {
                     cumF(g)+=Fishery_Survival*seasdur(s);
                     if(Fishery_Survival>maxF(g)) maxF(g)=Fishery_Survival;
                   }
                 }

             }   // end Pope's approx

             else          // Continuous F for method 2 or 3
             {
               equ_Z(s,p,g,a1)=natM(s,GP3(g),a1);
                 if(Fishon==1)
                 {
                   if(a1<=nages)
                   {
                     for (f=1;f<=Nfleet;f++)       //loop over fishing fleets to get Z
                     if (fleet_area(f)==p && Hrate(f,t)>0.0 && fleet_type(f)<=2)
                     {
                       equ_Z(s,p,g,a1)+=deadfish(s,g,f,a1)*Hrate(f,t);
                     }
                     if(save_for_report>0)
                     {
                       temp=equ_Z(s,p,g,a1)-natM(s,GP3(g),a1);
                       if(a>=Smry_Age && a<=nages) cumF(g)+=temp*seasdur(s);
                       if(temp>maxF(g)) maxF(g)=temp;
                     }
                   }
                 }
                 Nsurvive=N_beg*mfexp(-seasdur(s)*equ_Z(s,p,g,a1));

             }  //  end F method
             Survivors(p,g)=Nsurvive;
           }
           else
            {
               equ_Z(s,p,g,a1)=natM(s,GP3(g),a1);
            }
           }  // end pop
         }  // end morph

         if(Hermaphro_Option>0)
         {
           if(Hermaphro_seas==-1 || Hermaphro_seas==s)
           {
             for (p=1;p<=pop;p++)
             {
               k=gmorph/2;
               for (g=1;g<=k;g++)
               if(use_morph(g)>0)
               {
                 Survivors(p,g+k) += Survivors(p,g)*Hermaphro_val(GP4(g),a1); // increment males
                 Survivors(p,g) *= (1.-Hermaphro_val(GP4(g),a1)); // decrement females
               }
             }
           }
         }
          if(do_migration>0)  // movement between areas in equil calcs
          {
            Survivors2.initialize();
            for (g=1;g<=gmorph;g++)
            if(use_morph(g)>0)
            {
              for (p=1;p<=pop;p++)
              for (p2=1;p2<=pop;p2++)
              {
                k=move_pattern(s,GP4(g),p,p2);
                if(k>0) Survivors2(p2,g) += Survivors(p,g)*migrrate(bio_yr,k,a1);
              }  // end destination pop
            }
            Survivors=Survivors2;
          }  // end do migration
          
          for (g=1;g<=gmorph;g++)
          if(use_morph(g)>0)
          {
            for (p=1;p<=pop;p++)
            {
              if(s==nseas)  // into next age at season 1
              {
                if(a==3*nages)
                {
                  // end of the cohort
                }
                else if(a==(3*nages-1))           // do infinite tail; note that it uses Z from nseas as if it applies annually
                {
                  if(F_Method==1)
                  {
                    equ_numbers(1,p,g,a+1) = Survivors(p,g)/(1.-exp(-equ_Z(nseas,p,g,nages)));
                  }
                  else
                  {
                    equ_numbers(1,p,g,a+1) = Survivors(p,g)/(1.-exp(-equ_Z(nseas,p,g,nages)));
                  }
                }
                else
                {
                  equ_numbers(1,p,g,a+1) = Survivors(p,g);
                }
              }
              else
              {
                equ_numbers(s+1,p,g,a) = Survivors(p,g);  // same age, next season
              }

            }
          }
        }  // end season
     }  // end age

// now calc contribution to catch and ssb
       for (g=1;g<=gmorph;g++)
       if(use_morph(g)>0)
       {
         gg=sx(g);
         for (s=1;s<=nseas;s++)
         for (p=1;p<=pop;p++)
         {
           t=t_base+s;
           bio_t=bio_t_base+s;
           equ_numbers(s,p,g,nages)+=sum(equ_numbers(s,p,g)(nages+1,3*nages));
           if(Fishon==1)
           {
             if(F_Method>=2)
             {
               Zrate2(p,g)=elem_div( (1.-mfexp(-seasdur(s)*equ_Z(s,p,g))), equ_Z(s,p,g));
               if(s<Bseas(g)) Zrate2(p,g,0)=0.0;
               for (f=1;f<=Nfleet;f++)
               if (fleet_area(f)==p && fleet_type(f)<=2)
               if(Hrate(f,t)>0.0)
               {
                 equ_catch_fleet(2,s,f)+=Hrate(f,t)*elem_prod(equ_numbers(s,p,g)(0,nages),deadfish_B(s,g,f))*Zrate2(p,g);      // dead catch bio
                 equ_catch_fleet(5,s,f)+=Hrate(f,t)*elem_prod(equ_numbers(s,p,g)(0,nages),deadfish(s,g,f))*Zrate2(p,g);      // deadfish catch numbers
                 equ_catch_fleet(3,s,f)+=Hrate(f,t)*elem_prod(equ_numbers(s,p,g)(0,nages),sel_al_2(s,g,f))*Zrate2(p,g);      // retained catch bio
                   equ_catage(s,f,g)=elem_prod(elem_prod(equ_numbers(s,p,g)(0,nages),deadfish(s,g,f)) , Zrate2(p,g));
                   equ_catch_fleet(1,s,f)+=Hrate(f,t)*elem_prod(equ_numbers(s,p,g)(0,nages),sel_al_1(s,g,f))*Zrate2(p,g);      // encountered catch bio
                   equ_catch_fleet(4,s,f)+=Hrate(f,t)*elem_prod(equ_numbers(s,p,g)(0,nages),sel_al_3(s,g,f))*Zrate2(p,g);      // encountered catch bio
                   equ_catch_fleet(6,s,f)+=Hrate(f,t)*elem_prod(equ_numbers(s,p,g)(0,nages),sel_al_4(s,g,f))*Zrate2(p,g);      // retained catch numbers
               }
             }
             else  // F_method=1
             {
               // already done in the age loop
             }
           }

           if(s==1)
           {
             totbio += equ_numbers(s,p,g)(0,nages)*Wt_Age_beg(s,g)(0,nages);
             smrybio += equ_numbers(s,p,g)(Smry_Age,nages)*Wt_Age_beg(s,g)(Smry_Age,nages);
             smrynum += sum(equ_numbers(s,p,g)(Smry_Age,nages));
             smryage += equ_numbers(s,p,g)(Smry_Age,nages) * r_ages(Smry_Age,nages);
           }
//  SPAWN-RECR:   calc generation time, etc.
           if(s==spawn_seas)
           {
             if(gg==1)  // compute equilibrium spawning biomass for females
             {
              tempvec_a=elem_prod(equ_numbers(s,p,g)(0,nages),mfexp(-spawn_time_seas*equ_Z(s,p,g)(0,nages)));
               SPB_equil_pop_gp(p,GP4(g))+=tempvec_a*fec(g);
               equ_mat_bio+=elem_prod(equ_numbers(s,p,g)(0,nages),mfexp(-spawn_time_seas*equ_Z(s,p,g)(0,nages)))*make_mature_bio(GP4(g));
               equ_mat_num+=elem_prod(equ_numbers(s,p,g)(0,nages),mfexp(-spawn_time_seas*equ_Z(s,p,g)(0,nages)))*make_mature_numbers(GP4(g));
               GenTime+=tempvec_a*elem_prod(fec(g),r_ages);
             }
             else if(Hermaphro_Option>0 && gg==2)
             {
               tempvec_a=elem_prod(equ_numbers(s,p,g)(0,nages),mfexp(-spawn_time_seas*equ_Z(s,p,g)(0,nages)));
               MaleSPB_equil_pop_gp(p,GP4(g))+=tempvec_a*Wt_Age_beg(s,g)(0,nages);
             }
           }
         }
       }

     YPR_dead =   sum(equ_catch_fleet(2));    // dead yield per recruit
     YPR_N_dead = sum(equ_catch_fleet(5));    // dead numbers per recruit
     YPR_enc =    sum(equ_catch_fleet(1));    //  encountered yield per recruit
     YPR_ret =    sum(equ_catch_fleet(3));    // retained yield per recruit
     
   if(Fishon==1)
   {
     if(F_reporting<=1)
     {
       equ_F_std=YPR_dead/smrybio;
     }
     else if(F_reporting==2)
     {
       equ_F_std=YPR_N_dead/smrynum;
     }
     else if(F_reporting==3)
     {
       if(F_Method==1)
       {
         for (s=1;s<=nseas;s++)
         {
           t=t_base+s;
           for (f=1;f<=Nfleet;f++)
           {
             equ_F_std+=Hrate(f,t);
           }
         }
       }
       else
       {
         for (s=1;s<=nseas;s++)
         {
           t=t_base+s;
           for (f=1;f<=Nfleet;f++)
           {
             equ_F_std+=Hrate(f,t)*seasdur(s);
           }
         }
       }
     }
     else if(F_reporting==4)
     {
       temp1=0.0;
       temp2=0.0;
       for (g=1;g<=gmorph;g++)
       if(use_morph(g)>0)
       {
         for (p=1;p<=pop;p++)
         {
           for (a=F_reporting_ages(1);a<=F_reporting_ages(2);a++)   //  should not let a go higher than nages-2 because of accumulator
           {
             if(nseas==1)
             {
               temp1+=equ_numbers(1,p,g,a+1);
               temp2+=equ_numbers(1,p,g,a)*mfexp(-seasdur(1)*natM(1,GP3(g),a));
             }
             else
             {
               temp1+=equ_numbers(1,p,g,a+1);
               temp3=equ_numbers(1,p,g,a);  //  numbers at begin of year
               for (int kkk=1;kkk<=nseas;kkk++) {temp3*=mfexp(-seasdur(kkk)*natM(kkk,GP3(g),a));}
               temp2+=temp3;
             }
           }
         }
       }
       equ_F_std = log(temp2)-log(temp1);
     }
   }
   SPB_equil=sum(SPB_equil_pop_gp);
   GenTime/=SPB_equil;
   smryage /= smrynum;
   cumF/=(r_ages(nages)-r_ages(Smry_Age)+1.);
   if(Hermaphro_maleSPB==1) SPB_equil+=sum(MaleSPB_equil_pop_gp);

  }  //  end equil calcs
