%
% (c) The University of Glasgow, 1992-2003
%

Here we collect a variety of helper functions that construct or
analyse HsSyn.  All these functions deal with generic HsSyn; functions
which deal with the intantiated versions are located elsewhere:

   Parameterised by	Module
   ----------------     -------------
   RdrName		parser/RdrHsSyn
   Name			rename/RnHsSyn
   Id			typecheck/TcHsSyn	

\begin{code}
module HsUtils where

#include "HsVersions.h"

import HsBinds
import HsExpr
import HsPat
import HsTypes	
import HsLit

import RdrName		( RdrName, getRdrName, mkRdrUnqual )
import Var		( Id )
import Type		( Type )
import DataCon		( DataCon, dataConWrapId, dataConSourceArity )
import BasicTypes	( RecFlag(..) )
import OccName		( mkVarOcc )
import Name		( Name )
import SrcLoc
import FastString	( mkFastString )
import Outputable
import Util		( nOfThem )
import Bag
\end{code}


%************************************************************************
%*									*
	Some useful helpers for constructing syntax
%*									*
%************************************************************************

These functions attempt to construct a not-completely-useless SrcSpan
from their components, compared with the nl* functions below which
just attach noSrcSpan to everything.

\begin{code}
mkHsPar :: LHsExpr id -> LHsExpr id
mkHsPar e = L (getLoc e) (HsPar e)

mkSimpleMatch :: [LPat id] -> LHsExpr id -> Type -> LMatch id
mkSimpleMatch pats rhs rhs_ty
  = addCLoc (head pats) rhs $
    Match pats Nothing (GRHSs (unguardedRHS rhs) [] rhs_ty)

unguardedRHS :: LHsExpr id -> [LGRHS id]
unguardedRHS rhs@(L loc _) = [L loc (GRHS [L loc (ResultStmt rhs)])]

mkHsAppTy :: LHsType name -> LHsType name -> LHsType name
mkHsAppTy t1 t2 = addCLoc t1 t2 (HsAppTy t1 t2)

mkHsApp :: LHsExpr name -> LHsExpr name -> LHsExpr name
mkHsApp e1 e2 = addCLoc e1 e2 (HsApp e1 e2)

mkHsTyApp :: LHsExpr name -> [Type] -> LHsExpr name
mkHsTyApp expr []  = expr
mkHsTyApp expr tys = L (getLoc expr) (TyApp expr tys)

mkHsDictApp expr []	 = expr
mkHsDictApp expr dict_vars = L (getLoc expr) (DictApp expr dict_vars)

mkHsLam :: [LPat id] -> LHsExpr id -> LHsExpr id
mkHsLam pats body = mkHsPar (L (getLoc match) (HsLam match))
	where
	  match = mkSimpleMatch pats body placeHolderType

mkHsTyLam []     expr = expr
mkHsTyLam tyvars expr = L (getLoc expr) (TyLam tyvars expr)

mkHsDictLam []    expr = expr
mkHsDictLam dicts expr = L (getLoc expr) (DictLam dicts expr)

mkHsLet :: Bag (LHsBind name) -> LHsExpr name -> LHsExpr name
mkHsLet binds expr 
  | isEmptyBag binds = expr
  | otherwise        = L (getLoc expr) (HsLet [HsBindGroup binds [] Recursive] expr)

mkHsConApp :: DataCon -> [Type] -> [HsExpr Id] -> LHsExpr Id
-- Used for constructing dictinoary terms etc, so no locations 
mkHsConApp data_con tys args 
  = foldl mk_app (noLoc (HsVar (dataConWrapId data_con)) `mkHsTyApp` tys) args
  where
    mk_app f a = noLoc (HsApp f (noLoc a))

mkSimpleHsAlt :: LPat id -> LHsExpr id -> LMatch id
-- A simple lambda with a single pattern, no binds, no guards; pre-typechecking
mkSimpleHsAlt pat expr 
  = mkSimpleMatch [pat] expr placeHolderType

glueBindsOnGRHSs :: HsBindGroup id -> GRHSs id -> GRHSs id
glueBindsOnGRHSs binds1 (GRHSs grhss binds2 ty)
  = GRHSs grhss (binds1 : binds2) ty

-- These are the bits of syntax that contain rebindable names
-- See RnEnv.lookupSyntaxName

mkHsIntegral   i      = HsIntegral   i  placeHolderName
mkHsFractional f      = HsFractional f  placeHolderName
mkNPlusKPat n k       = NPlusKPatIn n k placeHolderName
mkHsDo ctxt stmts     = HsDo ctxt stmts [] placeHolderType

--- A useful function for building @OpApps@.  The operator is always a
-- variable, and we don't know the fixity yet.
mkHsOpApp e1 op e2 = OpApp e1 (noLoc (HsVar op)) (error "mkOpApp:fixity") e2

mkHsSplice e = HsSplice unqualSplice e

unqualSplice = mkRdrUnqual (mkVarOcc FSLIT("splice"))
		-- A name (uniquified later) to
		-- identify the splice

mkHsString s = HsString (mkFastString s)
\end{code}


%************************************************************************
%*									*
	Constructing syntax with no location info
%*									*
%************************************************************************

\begin{code}
nlHsVar :: id -> LHsExpr id
nlHsVar n = noLoc (HsVar n)

nlHsLit :: HsLit -> LHsExpr id
nlHsLit n = noLoc (HsLit n)

nlVarPat :: id -> LPat id
nlVarPat n = noLoc (VarPat n)

nlLitPat :: HsLit -> LPat id
nlLitPat l = noLoc (LitPat l)

nlHsApp :: LHsExpr id -> LHsExpr id -> LHsExpr id
nlHsApp f x = noLoc (HsApp f x)

nlHsIntLit n = noLoc (HsLit (HsInt n))

nlHsApps :: id -> [LHsExpr id] -> LHsExpr id
nlHsApps f xs = foldl nlHsApp (nlHsVar f) xs
	     
nlHsVarApps :: id -> [id] -> LHsExpr id
nlHsVarApps f xs = noLoc (foldl mk (HsVar f) (map HsVar xs))
		 where
		   mk f a = HsApp (noLoc f) (noLoc a)

nlConVarPat :: id -> [id] -> LPat id
nlConVarPat con vars = nlConPat con (map nlVarPat vars)

nlInfixConPat :: id -> LPat id -> LPat id -> LPat id
nlInfixConPat con l r = noLoc (ConPatIn (noLoc con) (InfixCon l r))

nlConPat :: id -> [LPat id] -> LPat id
nlConPat con pats = noLoc (ConPatIn (noLoc con) (PrefixCon pats))

nlNullaryConPat :: id -> LPat id
nlNullaryConPat con = noLoc (ConPatIn (noLoc con) (PrefixCon []))

nlWildConPat :: DataCon -> LPat RdrName
nlWildConPat con = noLoc (ConPatIn (noLoc (getRdrName con))
				   (PrefixCon (nOfThem (dataConSourceArity con) wildPat)))

nlTuplePat pats box = noLoc (TuplePat pats box)
wildPat  = noLoc (WildPat placeHolderType)	-- Pre-typechecking

nlHsDo :: HsStmtContext Name -> [LStmt id] -> LHsExpr id
nlHsDo ctxt stmts = noLoc (mkHsDo ctxt stmts)

nlHsOpApp e1 op e2 = noLoc (mkHsOpApp e1 op e2)

nlHsLam	match		= noLoc (HsLam match)
nlHsPar e		= noLoc (HsPar e)
nlHsIf cond true false	= noLoc (HsIf cond true false)
nlHsCase expr matches	= noLoc (HsCase expr matches)
nlTuple exprs box	= noLoc (ExplicitTuple exprs box)
nlList exprs		= noLoc (ExplicitList placeHolderType exprs)

nlHsAppTy f t		= noLoc (HsAppTy f t)
nlHsTyVar x		= noLoc (HsTyVar x)
nlHsFunTy a b		= noLoc (HsFunTy a b)

nlExprStmt expr		= noLoc (ExprStmt expr placeHolderType)
nlBindStmt pat expr	= noLoc (BindStmt pat expr)
nlLetStmt binds	 	= noLoc (LetStmt binds)
nlResultStmt expr	= noLoc (ResultStmt expr)
nlParStmt stuff		= noLoc (ParStmt stuff)
\end{code}



%************************************************************************
%*									*
		Bindings; with a location at the top
%*									*
%************************************************************************

\begin{code}
mkVarBind :: SrcSpan -> RdrName -> LHsExpr RdrName -> LHsBind RdrName
mkVarBind loc var rhs = mk_easy_FunBind loc var [] emptyBag rhs

mk_easy_FunBind :: SrcSpan -> RdrName -> [LPat RdrName]
		    -> LHsBinds RdrName -> LHsExpr RdrName
		    -> LHsBind RdrName

mk_easy_FunBind loc fun pats binds expr
  = L loc (FunBind (L loc fun) False{-not infix-} 
	[mk_easy_Match pats binds expr])

mk_easy_Match pats binds expr
  = mkMatch pats expr [HsBindGroup binds [] Recursive]
	-- The renamer expects everything in its input to be a
	-- "recursive" MonoBinds, and it is its job to sort things out
	-- from there.

mk_FunBind	:: SrcSpan 
		-> RdrName
		-> [([LPat RdrName], LHsExpr RdrName)]
		-> LHsBind RdrName

mk_FunBind loc fun [] = panic "TcGenDeriv:mk_FunBind"
mk_FunBind loc fun pats_and_exprs
  = L loc (FunBind (L loc fun) False{-not infix-} 
			[mkMatch p e [] | (p,e) <-pats_and_exprs])

mkMatch :: [LPat id] -> LHsExpr id -> [HsBindGroup id] -> LMatch id
mkMatch pats expr binds
  = noLoc (Match (map paren pats) Nothing 
		 (GRHSs (unguardedRHS expr) binds placeHolderType))
  where
    paren p = case p of
		L _ (VarPat _) -> p
		L l _	       -> L l (ParPat p)
\end{code}


%************************************************************************
%*									*
	Collecting binders from HsBindGroups and HsBinds
%*									*
%************************************************************************

Get all the binders in some HsBindGroups, IN THE ORDER OF APPEARANCE. eg.

...
where
  (x, y) = ...
  f i j  = ...
  [a, b] = ...

it should return [x, y, f, a, b] (remember, order important).

\begin{code}
collectGroupBinders :: [HsBindGroup name] -> [Located name]
collectGroupBinders groups = foldr collect_group [] groups
	where
	  collect_group (HsBindGroup bag sigs is_rec) acc
	 	= foldrBag (collectAcc . unLoc) acc bag
	  collect_group (HsIPBinds _) acc = acc


collectAcc :: HsBind name -> [Located name] -> [Located name]
collectAcc (PatBind pat _) acc = collectLocatedPatBinders pat ++ acc
collectAcc (FunBind f _ _) acc = f : acc
collectAcc (VarBind f _) acc  = noLoc f : acc
collectAcc (AbsBinds _ _ dbinds _ binds) acc
  = [noLoc dp | (_,dp,_) <- dbinds] ++ acc
	-- ++ foldr collectAcc acc binds
	-- I don't think we want the binders from the nested binds
	-- The only time we collect binders from a typechecked 
	-- binding (hence see AbsBinds) is in zonking in TcHsSyn

collectHsBindBinders :: Bag (LHsBind name) -> [name]
collectHsBindBinders binds = map unLoc (collectHsBindLocatedBinders binds)

collectHsBindLocatedBinders :: Bag (LHsBind name) -> [Located name]
collectHsBindLocatedBinders binds = foldrBag (collectAcc . unLoc) [] binds
\end{code}


%************************************************************************
%*									*
	Getting pattern signatures out of bindings
%*									*
%************************************************************************

Get all the pattern type signatures out of a bunch of bindings

\begin{code}
collectSigTysFromHsBinds :: [LHsBind name] -> [LHsType name]
collectSigTysFromHsBinds binds = concat (map collectSigTysFromHsBind binds)

collectSigTysFromHsBind :: LHsBind name -> [LHsType name]
collectSigTysFromHsBind bind
  = go (unLoc bind)
  where
    go (PatBind pat _)  = collectSigTysFromPat pat
    go (FunBind f _ ms) = go_matches (map unLoc ms)

	-- A binding like    x :: a = f y
	-- is parsed as FunMonoBind, but for this purpose we 	
	-- want to treat it as a pattern binding
    go_matches []				 = []
    go_matches (Match [] (Just sig) _ : matches) = sig : go_matches matches
    go_matches (match		      : matches) = go_matches matches
\end{code}

%************************************************************************
%*									*
	Getting binders from statements
%*									*
%************************************************************************

\begin{code}
collectStmtsBinders :: [LStmt id] -> [Located id]
collectStmtsBinders = concatMap collectLStmtBinders

collectLStmtBinders = collectStmtBinders . unLoc

collectStmtBinders :: Stmt id -> [Located id]
  -- Id Binders for a Stmt... [but what about pattern-sig type vars]?
collectStmtBinders (BindStmt pat _)   = collectLocatedPatBinders pat
collectStmtBinders (LetStmt binds)    = collectGroupBinders binds
collectStmtBinders (ExprStmt _ _)     = []
collectStmtBinders (ResultStmt _)     = []
collectStmtBinders (RecStmt ss _ _ _) = collectStmtsBinders ss
collectStmtBinders other              = panic "collectStmtBinders"
\end{code}
