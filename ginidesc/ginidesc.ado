*! version 1 Roger Aliaga y Silvia Montoya, Marzo 1999
*! Gini decomposition in within- and between-groups inequality
*! Syntax: ginidesc <var> [[w=weight] if <exp> in <range>], 
*!		by(<groupvar>) Mat(<matrixname>) GKmat(<matrixname>)

program define ginidesc
	version 6.0
	
	program drop ginidesc

	local varlist "req ex max(1)"
	local if "opt"
	local in "opt"
	local options "BYgroup(string) Mat(string) GKmat(string)"
	local weight "aweight fweight"
	parse "`*'"
	parse "`varlist'", parse (" ")
	local inc "`1'"

	tempvar aa bb pi1 tot pi grupos indice part Desig wi touse cc GGk
	tempname a i gini g_o g_b g_w part mean gins meanas A rpi gini_b gini_w vvv

	if "`weight'" == "" {ge `wi' = 1}
	else {ge `wi' `exp'}

	mark `touse' `if' `in'
	markout `touse' `varlist' `bygroup'
	lab var `touse' "All obs"
	lab def `touse' 1 " "
	lab val `touse' `touse'
	
	set more 1

quietly {
	count if `inc' < 0 & `touse'
	local ct = _result(1)
	if `ct' > 0 {
		noi di " "
		noi di in blue "Warning: `inc' has `ct' values < 0." _c
		noi di in blue " Not used in calculations"
		}
	count if `inc' == 0 & `touse'
	local ct = _result(1)
	if `ct' > 0 {
		noi di " "
		noi di in blue "Warning: `inc' has `ct' values = 0." _c
		noi di in blue "Used in calculations"
		}

preserve
drop if ~`touse'
egen `aa'=mean(`inc'), by(`bygroup')
sort `aa'
egen `bb'=group(`aa')
sort `bb'
local co=`bb'[_N]

* Vector part de participación de cada grupo en la pob total

tabulate `bb' [w = `wi'], matcell(`part')
scalar `a'=0

for numlist 1/`co': scalar `a'=scalar(`a')+`part'[X,1]
for numlist 1/`co': scalar aX=`part'[X,1]/scalar(`a')
for numlist 1/`co': mat `part'[X,1]=scalar(aX)
for numlist 1/`co': scalar drop aX

* Vector mean de medias por grupo

mat `mean'=J(`co',1,0)

sort `bb'
local i=1
while `i'<=`co' {
	summ `inc' [w = `wi'] if `bb'==`i'
	mat `mean'[`i',1]=r(mean)
	local i=`i'+1
}

* Vector gins de ginis por grupo

mat `gins'=J(`co',`co',0)

sort `bb'
local i=1
while `i'<=`co' {
	ineqdeco `inc' [w = `wi'] if `bb'==`i'
	mat `gins'[`i',`i']=$S_gini
	local i=`i'+1
}
mat list `gins'

* Matriz diagonal de medias

mat `meanas'=diag(`mean')

* Matriz para la normalización A

mat `A'=J(`co',`co',0)

local i=1
while `i'<=`co' {
	local j=1
	while `j'<=`co' {
		mat `A'[`i',`j']=cond(`i'>`j',1,0)
		local j=`j'+1
	}
local i=`i'+1
}
* Vector rpi de participación de cada grupo en el ingreso total

egen `pi1'=sum(`inc'*`wi'), by(`bb')
egen `tot'=sum(`inc'*`wi')
gen `pi'=`pi1'/`tot'

collapse `pi', by(`bb')
mat `rpi'=J(`co',1,0)
for numlist 1/`co': mat `rpi'[X,1]=`pi'[X]
restore, preserve
cap drop if ~`touse'

* CALCULO DEL GINI TOTAL Y POR GRUPOS

qui ineqdeco `inc' [w = `wi']
scalar `gini'=$S_gini

mat `gini_b'=`rpi''*(inv(`meanas')*`A''*`meanas'-`A'')*`part'
mat `gini_w'=`rpi''*`gins'*`part'
scalar `g_o'=scalar(`gini')-`gini_b'[1,1]-`gini_w'[1,1]
scalar `g_b'=`gini_b'[1,1]
scalar `g_w'=`gini_w'[1,1]

keep in 1/4
gen str5 `grupos'="Gini"
replace `grupos'="Between" in 2
replace `grupos'="Within" in 3
replace `grupos'="Overlap" in 4
keep `grupos'
label var `grupos' "Grupos"

gen `indice'=scalar(`gini')
replace `indice'=scalar(`g_b') if `grupos'=="Between" 
replace `indice'=scalar(`g_w') if `grupos'=="Within" 
replace `indice'=scalar(`g_o') if `grupos'=="Overlap" 
label var `indice' "Indice"

gen `part'=100
replace `part'=scalar(`g_b')/scalar(`gini')*100 if `grupos'=="Between"
replace `part'=scalar(`g_w')/scalar(`gini')*100 if `grupos'=="Within"
replace `part'=scalar(`g_o')/scalar(`gini')*100 if `grupos'=="Overlap"
label var `part' "Part."

gen str5 `Desig'="TOTAL" if `grupos'=="Gini"
replace `Desig'="DESCOMP." if `grupos'~="Gini"
label var `Desig' "Desig"

if "`mat'"~="" {
mkmat `indice' `part', mat(`mat')
mat rown `mat'=Gini Between Within Overlap
mat coln `mat'=Indices Part
}
}
noi di "                  "
noi di in green "Pyatt's Inequality decomposition"
tabdisp `grupos', cell(`indice' `part') concise left by(`Desig') format(%9.3f)
noi di in green "Stored in matrix" in yellow " `mat'"

qui {
restore, preserve
egen `aa'=mean(`inc'), by(`bygroup')
sort `aa'
egen `bb'=group(`aa')
sort `bb'
local co=`bb'[_N]

collapse `bb', by(`bygroup')
sort `bb'

gen `GGk'=0
for numlist 1/`co': replace `GGk'=`gins'[X,X] in X
label var `GGk' "Gini_k"
label var `bygroup' "K"

if "`gkmat'"~="" {
mkmat `GGk', mat(`gkmat')
mkmat `bygroup', mat(`vvv')
mat `gkmat'=`vvv',`gkmat'
mat rown `gkmat'=k
mat coln `gkmat'=k Gini_k
}
}
noi di "                  "
noi di in green "Gini Coefficient by subgroups"
noi di in green "of" in yellow " `bygroup'"
tabdisp `bygroup', cell(`GGk') concise left format(%9.3f)
noi di in green "Stored in matrix" in yellow " `gkmat'"
discard
end
