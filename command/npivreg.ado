/* 
Estimation of Nonparametric instrumental variable (NPIV) models

Version 1.0.0 25th Sep 2016

This program estimates the function g(x) in

Y = g(X) + e with E(e|Z)=0

where Y is a scalar dependent variable ("depvar"), 
X is a scalar endogenous variable ("expvar"), and 
Z a scalar instrument ("inst").

Syntax:
npivreg depvar expvar inst [, power_exp(#) power_inst(#) num_exp(#) num_inst(#) polynomial increasing decreasing] 

where power_exp is the power of basis functions for x (defalut = 2),
power_inst is the power of basis functions for z (defalut = 3),
num_exp is the number of knots for x (defalut = 2),
num_inst is the number of knots for z (defalut = 3), 
polonomial option gives the basis functions for polynomial spline (default is bslpline).

# shape restrictions (bspline is used - power of bslpine for "expvar" is fixed to 2.
increasing option imposes a increasing shape restriction on function g(X).
decreasing option imposes a decreasing shape restriction on function g(X).

When polynomial is used, shape restrictions cannot be imposed.
(an error message will come out)

Users can freely modify the power and the type of basis functions and the number of knots
when shape restrictions are not imposed.

If unspecified, the command runs on a default setting.
*/

program define npivreg
		version 12
		
		// initializations
		syntax varlist(numeric) [, power_exp(integer 2) power_inst(integer 3) num_exp(integer 2) num_inst(integer 3) pctile(integer 5) polynomial increasing decreasing]
		display "varlist is `varlist'"
		
		// generate temporary names to avoid any crash in Stata spaces
		tempname b p Yhat depvar expvar inst powerx powerz xmin xmax x_distance zmin zmax z_distance upctile
		tempvar xlpct xupct zlpct zupct beta P
		
		// eliminate any former NPIV regression results
		capture drop basisexpvar* basisinst* gridpoint*
		capture drop npest* grid* beta*
		
		// check whether required commands are installed
		// capture ssc install bspline
		// capture ssc install polyspline
		
		// macro assignments		
		global mylist `varlist'
		global depvar   : word 1 of $mylist
		global expvar   : word 2 of $mylist
		global inst     : word 3 of $mylist
		global powerx `power_exp'
		global powerz `power_inst'
		local upctile = 100 - `pctile'
				
		//equidistance nodes (knots) are generated for x from pctile (default = 5) to upctile(default = 95)
		quietly egen `xlpct' = pctile($expvar), p(`pctile')
		quietly egen `xupct' = pctile($expvar), p(`upctile')
		quietly egen `zlpct' = pctile($inst), p(`pctile')
		quietly egen `zupct' = pctile($inst), p(`upctile')
		global xmin = `xlpct'
		global xmax = `xupct'
		global x_distance = ($xmax - $xmin)/(`num_exp' - 1 )
		
		//equidistance nodes (knots) are generated for z from pctile (default = 5) to upctile(default = 95)
		quietly summarize $inst
		global zmin = `zlpct'
		global zmax = `zupct'
		global z_distance = ($zmax - $zmin)/(`num_inst' - 1)
        
		//fine grid for fitted value of g(X)
		mata : grid = rangen($xmin, $xmax, rows(st_data(., "$expvar")))
		mata : st_addvar("float", "grid")
		mata : st_store(., "grid", grid)
		
		// generate bases for X and Z
	    // If the option "polynomial" is not typed, bspline is used.
		if "`polynomial'" == "" {
		// check whether increasing option is used        
		if "`increasing'" == "increasing" {
		capture drop basisexpvar* basisinst* npest*
		quietly bspline, xvar(grid) gen(gridpoint) knots($xmin($x_distance)$xmax) power(2) 
        quietly bspline, xvar($expvar) gen(basisexpvar) knots($xmin($x_distance)$xmax) power(2)
		quietly bspline, xvar($inst) gen(basisinst) knots($zmin($z_distance)$zmax) power($powerz)
		mata : npiv_optimize("$depvar", "basisexpvar*", "basisinst*", "`b'", "`p'", "`Yhat'")
		}
		// check whether decreasing option is used
		else if "`decreasing'" == "decreasing" {
		capture drop basisexpvar* basisinst* npest*
		quietly bspline, xvar(grid) gen(gridpoint) knots($xmin($x_distance)$xmax) power(2) 
        quietly bspline, xvar($expvar) gen(basisexpvar) knots($xmin($x_distance)$xmax) power(2)
		quietly bspline, xvar($inst) gen(basisinst) knots($zmin($z_distance)$zmax) power($powerz)
		mata : npiv_optimize_dec("$depvar", "basisexpvar*", "basisinst*", "`b'", "`p'", "`Yhat'")
		}
		// procedure without shape restrictions
		else {
		capture drop basisexpvar* basisinst* npest*
		quietly bspline, xvar(grid) gen(gridpoint) knots($xmin($x_distance)$xmax) power($powerx) 
        quietly bspline, xvar($expvar) gen(basisexpvar) knots($xmin($x_distance)$xmax) power($powerx)
		quietly bspline, xvar($inst) gen(basisinst) knots($zmin($z_distance)$zmax) power($powerz)
		mata : npiv_estimation("$depvar", "basisexpvar*", "basisinst*", "`b'", "`p'", "`Yhat'")
		}
		}
		
		// If polyspline is typed
        else {
		// check whether increasing option is used
		if("`increasing'" == "increasing"){
			display in red "shape restriction (increasing) not allowed"	
			error 498
		}
		
		// check whether decreasing option is used
		else if("`decreasing'" == "decreasing"){
			display in red "shape restriction (decreasing) not allowed"	
			error 498
		}
		
		else {
		capture drop basisexpvar* basisinst* npest*
		quietly polyspline grid, gen(gridpoint) refpts($xmin($x_distance)$xmax) power($powerx) 
        quietly polyspline $expvar, gen(basisexpvar) refpts($xmin($x_distance)$xmax) power($powerx) 
		quietly polyspline $inst, gen(basisinst) refpts($zmin($z_distance)$zmax) power($powerz) 
		
		mata : npiv_estimation("$depvar", "basisexpvar*", "basisinst*", "`b'", "`p'", "`Yhat'")
		}
		}
				
		// convert the Stata matrices to Stata variable
		svmat `Yhat', name(npest)  // NPIV estimate
		svmat `p', name(`P')       // basis functions for x (not returned)
		svmat `b', name(beta)    // coefficients for series estimate (not returned)
		label variable npest "NPIV fitted value"
		drop basisexpvar* basisinst* gridpoint*
end


// Define a Mata function computing NPIV estimates without shape restriction
mata:
void npiv_estimation(string scalar vname, string scalar basisname1, 
                     string scalar basisname2, string scalar bname, 
					 string scalar pname, string scalar estname)

{
    real vector Y, b, Yhat
	real matrix P, Q, MQ
	// load bases from Stata variable space
	P 		= st_data(., basisname1)
	Q 		= st_data(., basisname2)
	Y 		= st_data(., vname)
	
	// compute the estimate by the closed form solution
	MQ 		= Q*invsym(Q'*Q)*Q'
	b  		= invsym(P'*MQ*P)*P'*MQ*Y
	GP      = st_data(., "gridpoint*") // spline bases on fine grid points
	Yhat 	= GP*b //fitted value on fine grid
		
	// store the mata results into the Stata matrix space
	// st_matrix("bb", b)
	st_matrix(bname, b)
	st_matrix(pname, P)
	st_matrix(estname, Yhat)           
}

// Define a Mata function computing NPIV estimates with increasing shape restriction
void npiv_optimize(string scalar vname, string scalar basisname1, 
                   string scalar basisname2, string scalar bname, 
				   string scalar pname, string scalar estname)
					 
{    	real vector Y, beta, Yhat
		real matrix P, Q
		real scalar n

        P 		= st_data(., basisname1)
		Q 		= st_data(., basisname2)
		Y 		= st_data(., vname)
 		n       = cols(P)
		
	    // optimisation routine for the minimisation problem
    	S 		= optimize_init()
		ival    = J(1, n, 1)

		optimize_init_argument(S, 1, P)
		optimize_init_argument(S, 2, Q)
		optimize_init_argument(S, 3, Y)
        optimize_init_evaluator(S, &objfn())
        optimize_init_params(S, ival)
		optimize_init_technique(S, "nr")
        optimize_init_which(S, "min")
		optimize_init_conv_ptol(S, 1e-5)
		optimize_init_conv_vtol(S, 1e-5)
		optimize_init_conv_ignorenrtol(S, "on")
		temp    = optimize(S) // parameter estimated by optimisation
     	beta    = J(1, n, 0)
		prebeta = J(1, n, 0)
		
		for (i = 1; i<=n; i++) {
		   prebeta[i] = exp(temp)[i]
		   beta[i]    = sum(prebeta)
		   }
		   
		GP      = st_data(., "gridpoint*") // spline bases on fine grid points
		Yhat 	= GP*beta' //fitted value on fine grid
		
		// store the mata results into the Stata matrix space
		st_matrix(bname, beta)
		st_matrix(pname, P)
		st_matrix(estname, Yhat)           
}

// Define a Mata function computing NPIV estimates with decreasing shape restriction
void npiv_optimize_dec(string scalar vname, string scalar basisname1, 
                       string scalar basisname2, string scalar bname, 
				       string scalar pname, string scalar estname)
					 
{    	real vector Y, beta, Yhat
		real matrix P, Q
		real scalar n

        P 		= st_data(., basisname1)
		Q 		= st_data(., basisname2)
		Y 		= st_data(., vname)
 		n       = cols(P)
		
	    // optimisation routine for the minimisation problem
    	S 		= optimize_init()
		ival    = J(1, n, 1)

		optimize_init_argument(S, 1, P)
		optimize_init_argument(S, 2, Q)
		optimize_init_argument(S, 3, Y)
        optimize_init_evaluator(S, &objfn_dec())
        optimize_init_params(S, ival)
		optimize_init_technique(S, "nr")
        optimize_init_which(S, "min")
		optimize_init_conv_ptol(S, 1e-5)
		optimize_init_conv_vtol(S, 1e-5)
		optimize_init_conv_ignorenrtol(S, "on")
		temp    = optimize(S) // parameter estimated by optimisation
     	beta    = J(1, n, 0)
		prebeta = J(1, n, 0)
		
		for (i = 1; i<=n; i++) {
		   prebeta[i] = -exp(temp)[i]
		   beta[i]    = sum(prebeta)
		   }
		   
		GP      = st_data(., "gridpoint*") // spline bases on fine grid points
		Yhat 	= GP*beta' //fitted value on fine grid
		
		// store the mata results into the Stata matrix space
		st_matrix(bname, beta)
		st_matrix(pname, P)
		st_matrix(estname, Yhat)           
}

// objective function for minimisation with increasing OPTION
void objfn(real scalar todo, real vector B, real matrix P, 
           real matrix Q, real vector Y, val, grad, hess) 
		   
{		real matrix MQ 
		MQ      = Q*invsym(Q'*Q)*Q'
		n       = cols(P)
		bb      = J(1, n, 0)
		prebb   = J(1, n, 0)
		for (i = 1; i<=n; i++) {
		   prebb[i] = exp(B)[i]
		   bb[i]    = sum(prebb)
		   }
		   
		val = (Y - P*bb')'*MQ*(Y-P*bb')
}

// objective function for minimisation with decreasing OPTION
void objfn_dec(real scalar todo, real vector B, real matrix P, 
               real matrix Q, real vector Y, val, grad, hess) 
		   
{		real matrix MQ 
		MQ      = Q*invsym(Q'*Q)*Q'
		n       = cols(P)
		bb      = J(1, n, 0)
		prebb   = J(1, n, 0)
		for (i = 1; i<=n; i++) {
		   prebb[i] = -exp(B)[i]
		   bb[i]    = sum(prebb)
		   }
		   
		val = (Y - P*bb')'*MQ*(Y-P*bb')
}

 end
