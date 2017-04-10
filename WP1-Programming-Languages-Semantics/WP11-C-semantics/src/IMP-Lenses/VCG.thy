section \<open>Verification Condition Testing\<close>

theory VCG
  imports "utp/utp_hoare"
begin

subsection \<open>Tactics for Theorem Proving\<close>
text \<open>The tactics below are used to prove the validity of complex Hoare triples/expressions
semi-automatically in a more efficient manner than using @{method rel_auto} by itself.\<close>

subsection \<open>Using Eisbach methods\<close>
(* apparently `|` has lower precedence than `,` , so method `a, b|c` is equivalent to `(a, b)|c` *)

text \<open>Some proof subgoals require extra cleanup beyond plain simp/auto, so we need a simpset for
those.\<close>
named_theorems last_simps
declare lens_indep_sym[last_simps]
declare mod_pos_pos_trivial[last_simps]

text \<open>Some proof subgoals require theorem unfolding.\<close>
named_theorems unfolds
declare lens_indep_def[unfolds]

method assume_steps =
  rule seq_hoare_r,
  rule assume_hoare_r,
  rule skip_hoare_r

(* trying with other while loops to find the right patterns *)
method even_count declares unfolds last_simps =
  rule seq_hoare_r;
  (rule seq_hoare_r[of _ _ true])?,
  (rule assigns_hoare_r'|rule assigns_hoare_r),
  (* ? needed as it attempts application of the rule to the first subgoal as well *)
  assume_steps?;
  (rule while_invr_hoare_r)?, (* ? needed again to avoid error *)
  (rule seq_hoare_r)?;
  (rule assigns_hoare_r')?,
  (rule cond_hoare_r)?,
  (unfold unfolds)?,
  insert last_simps;
  rel_auto

method increment declares unfolds =
  rule seq_hoare_r[of _ _ true];
  (rule assigns_hoare_r'|rule assigns_hoare_r)?,
  assume_steps?;
  (rule while_invr_hoare_r)?,
  unfold unfolds,
  rel_auto+

method double_increment declares unfolds =
  rule seq_hoare_r[of _ _ true],
  rule while_invr_hoare_r,
  unfold unfolds,
  rel_auto+,
  assume_steps,
  rel_auto,
  rule while_invr_hoare_r,
  rel_auto+

method if_increment declares unfolds =
  unfold unfolds,
  rule cond_hoare_r;
  rule while_invr_hoare_r, rel_auto+

method rules =
  (rule seq_hoare_r|
    rule skip_hoare_r|
    rule while_invr_hoare_r|
    (rule cond_hoare_r; simp?, (rule hoare_false)?)| (* not sure if s/,/;/ is needed *)
    rule assigns_hoare_r'| (* infixr seqr means this is not useful chained with seq rule *)
    rule assert_hoare_r|
    rule assume_hoare_r
  )+

method rules_x =
  rule seq_hoare_r|
  rule skip_hoare_r|
  rule cond_hoare_r|
  rule assigns_hoare_r'| (* merges two subgoals? *)
  rule assigns_hoare_r|  (* may not be useful *)
  rule assert_hoare_r|
  rule assume_hoare_r|
  rule while_hoare_r|
  rule while_hoare_r'|
  rule while_invr_hoare_r

(* also have simp versions *)
method utp_methods = rel_auto|rel_blast|pred_auto|pred_blast

method vcg declares last_simps unfolds =
  if_increment unfolds: unfolds|
  even_count last_simps: last_simps unfolds: unfolds|
  double_increment unfolds: unfolds|
  increment unfolds: unfolds|
(*   (intro hoare_r_conj)?; (* intro rather than rule means it will be repeatedly applied; this may
not actually be useful (it's certainly not necessary) and so is currently commented out *) *)
    rules?;
    utp_methods,
    (auto simp: last_simps)?

text \<open>VCG for partial solving; applies a Hoare rule to the first subgoal (possibly generating more
subgoals) and then attempts to solve it and any simply-solvable immediately-succeeding goals.
For now, \texttt{rule seq_hoare_r[of _ _ true]}, which must precede the seq-assume-skip, will be
applied manually. For certain programs, we need to do utp_methods first (in fact, for some it's all
that's needed), but this results in slowdowns for other programs that do not require it first and in
fact some rules are not properly applied if the application does not come before utp_methods usage.\<close>
method vcg_step = utp_methods|rules_x, utp_methods?

(* Need weakest precondition reasoning? *)

subsubsection \<open>Building swap (SEQ+ASN)\<close>

lemma swap_test:
  assumes "weak_lens x" and "weak_lens y" and "weak_lens z"
      and "x \<bowtie> y" and "x \<bowtie> z" and "y \<bowtie> z"
  shows "\<lbrace>&x =\<^sub>u \<guillemotleft>a\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>b\<guillemotright>\<rbrace>
          z :== &x;;
          x :== &y;;
          y :== &z
         \<lbrace>&x =\<^sub>u \<guillemotleft>b\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>a\<guillemotright>\<rbrace>\<^sub>u"
  using assms
  by rel_auto (simp add: lens_indep_sym)

lemma swap_test_manual:
  assumes "weak_lens x" and "weak_lens y" and "weak_lens z"
      and "x \<bowtie> y" and "x \<bowtie> z" and "y \<bowtie> z"
  shows "\<lbrace>&x =\<^sub>u \<guillemotleft>a\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>b\<guillemotright>\<rbrace>
          z :== &x;;
          x :== &y;;
          y :== &z
         \<lbrace>&x =\<^sub>u \<guillemotleft>b\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>a\<guillemotright>\<rbrace>\<^sub>u"
  apply (insert assms)

  apply (rule seq_hoare_r)
  prefer 2
  apply (rule seq_hoare_r)
  apply (rule assigns_hoare_r')
  apply (rule assigns_hoare_r')

  apply rel_simp
  apply (simp add: lens_indep_sym)
  done

lemma swap_test_method:
  assumes "weak_lens x" and "weak_lens y" and "weak_lens z"
      and "x \<bowtie> y" and "x \<bowtie> z" and "y \<bowtie> z"
  shows "\<lbrace>&x =\<^sub>u \<guillemotleft>a\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>b\<guillemotright>\<rbrace>
          z :== &x;;
          x :== &y;;
          y :== &z
         \<lbrace>&x =\<^sub>u \<guillemotleft>b\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>a\<guillemotright>\<rbrace>\<^sub>u"
  using assms
  by vcg

lemma swap_test_method_step:
  assumes "weak_lens x" and "weak_lens y" and "weak_lens z"
      and "x \<bowtie> y" and "x \<bowtie> z" and "y \<bowtie> z"
  shows "\<lbrace>&x =\<^sub>u \<guillemotleft>a\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>b\<guillemotright>\<rbrace>
          z :== &x;;
          x :== &y;;
          y :== &z
         \<lbrace>&x =\<^sub>u \<guillemotleft>b\<guillemotright> \<and> &y =\<^sub>u \<guillemotleft>a\<guillemotright>\<rbrace>\<^sub>u"
  apply (insert assms)
  unfolding lens_indep_def
  apply vcg_step
  done

lemma swap_testx:
  assumes "weak_lens x" and "weak_lens y" and "weak_lens z"
      and "x \<bowtie> y"
      and "x \<sharp> a" and "y \<sharp> a" and "z \<sharp> a"
      and "x \<sharp> b" and "y \<sharp> b" and "z \<sharp> b"
  shows "\<lbrace>&x =\<^sub>u a \<and> &y =\<^sub>u b\<rbrace>
          z :== &x;;
          x :== &y;;
          y :== &z
         \<lbrace>&x =\<^sub>u b \<and> &y =\<^sub>u a\<rbrace>\<^sub>u = \<lbrace>&x =\<^sub>u a \<and> &y =\<^sub>u b\<rbrace>
          z :== &x;;
          x :== &y
         \<lbrace>&x =\<^sub>u b \<and> &z =\<^sub>u a\<rbrace>\<^sub>u"
  using assms
  by rel_simp

subsubsection \<open>Building COND\<close>

lemma if_true:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> true \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 - exp\<^sub>2\<rbrace>\<^sub>u"
  using assms
  by rel_simp

lemma if_true_manual:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> true \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 - exp\<^sub>2\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule cond_hoare_r)
  defer
  apply simp
  apply (rule hoare_false)

  apply simp
  apply rel_simp
  done

lemma if_true_method:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> true \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 - exp\<^sub>2\<rbrace>\<^sub>u"
  using assms
  by vcg

lemma if_true_method_step:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> true \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 - exp\<^sub>2\<rbrace>\<^sub>u"
  by (insert assms) vcg_step

lemma if_false:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> false \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 + exp\<^sub>2\<rbrace>\<^sub>u"
  using assms
  by rel_simp

lemma if_false_manual:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> false \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 + exp\<^sub>2\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule cond_hoare_r)
  
  apply simp
  apply (rule hoare_false)

  apply simp
  apply rel_auto
  done

lemma if_false_method:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> false \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 + exp\<^sub>2\<rbrace>\<^sub>u"
  using assms
  by vcg

lemma if_false_method_step:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>1"
      and "x \<sharp> exp\<^sub>2"
  shows "\<lbrace>&x =\<^sub>u exp\<^sub>1\<rbrace>
          x :== &x - exp\<^sub>2 \<triangleleft> false \<triangleright>\<^sub>r (x :== &x + exp\<^sub>2)
         \<lbrace>&x =\<^sub>u exp\<^sub>1 + exp\<^sub>2\<rbrace>\<^sub>u"
  by (insert assms) vcg_step

lemma if_base:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>2"
      and "x \<sharp> exp\<^sub>3"
  shows "\<lbrace>true\<rbrace>
          x :== exp\<^sub>2 \<triangleleft> exp\<^sub>1 \<triangleright>\<^sub>r (x :== exp\<^sub>3)
         \<lbrace>&x =\<^sub>u exp\<^sub>2 \<or> &x =\<^sub>u exp\<^sub>3\<rbrace>\<^sub>u"
  using assms
  by rel_auto

lemma if_manual:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>2"
      and "x \<sharp> exp\<^sub>3"
  shows "\<lbrace>true\<rbrace>
          x :== exp\<^sub>2 \<triangleleft> exp\<^sub>1 \<triangleright>\<^sub>r (x :== exp\<^sub>3)
         \<lbrace>&x =\<^sub>u exp\<^sub>2 \<or> &x =\<^sub>u exp\<^sub>3\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule cond_hoare_r)
  apply simp

  defer
  apply simp

  apply rel_simp
  apply pred_simp (* needed for UTP predicates; pred_blast needed for sets *)
  done

lemma if_method:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>2"
      and "x \<sharp> exp\<^sub>3"
  shows "\<lbrace>true\<rbrace>
          x :== exp\<^sub>2 \<triangleleft> exp\<^sub>1 \<triangleright>\<^sub>r (x :== exp\<^sub>3)
         \<lbrace>&x =\<^sub>u exp\<^sub>2 \<or> &x =\<^sub>u exp\<^sub>3\<rbrace>\<^sub>u"
  using assms
  by vcg

lemma if_method_step:
  assumes "weak_lens x"
      and "x \<sharp> exp\<^sub>2"
      and "x \<sharp> exp\<^sub>3"
  shows "\<lbrace>true\<rbrace>
          x :== exp\<^sub>2 \<triangleleft> exp\<^sub>1 \<triangleright>\<^sub>r (x :== exp\<^sub>3)
         \<lbrace>&x =\<^sub>u exp\<^sub>2 \<or> &x =\<^sub>u exp\<^sub>3\<rbrace>\<^sub>u"
  by (insert assms) vcg_step

subsubsection \<open>Building WHILE\<close>

lemma even_count_manual:
  assumes "vwb_lens i" and "weak_lens a" and "vwb_lens j" and "weak_lens n"
      and "i \<bowtie> a" and "i \<bowtie> j" and "i \<bowtie> n" and "a \<bowtie> j" and "a \<bowtie> n" and "j \<bowtie> n"
  shows
  "\<lbrace>&a =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &n =\<^sub>u 1\<rbrace>
      i :== &a ;; j :== 0 ;;
      (&a =\<^sub>u 0 \<and> &n =\<^sub>u 1 \<and> &j =\<^sub>u 0 \<and> &i =\<^sub>u &a)\<^sup>\<top> ;;
    while &i <\<^sub>u &n
      invr &a =\<^sub>u 0 \<and> &n =\<^sub>u 1 \<and> &j =\<^sub>u (((&i + 1) - &a) div 2) \<and> &i \<le>\<^sub>u &n \<and> &i \<ge>\<^sub>u &a
      do (j :== &j + 1 \<triangleleft> &i mod 2 =\<^sub>u 0 \<triangleright>\<^sub>r II) ;; i :== &i + 1 od
    \<lbrace>&j =\<^sub>u 1\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule seq_hoare_r)
   prefer 2
   apply (rule seq_hoare_r[of _ _ true](* , rule hoare_true *))
   apply (rule assigns_hoare_r')
   apply (rule seq_hoare_r)
    apply (rule assume_hoare_r)
    apply (rule skip_hoare_r)
   prefer 2
   apply (rule while_invr_hoare_r)
     apply (rule seq_hoare_r)
      prefer 2
      apply (rule assigns_hoare_r')
     apply (rule cond_hoare_r)
      prefer 6
      unfolding lens_indep_def
      apply rel_auto
     apply rel_auto
     using mod_pos_pos_trivial
    apply rel_auto
   apply rel_auto
  apply rel_auto
  apply rel_auto
  done

lemma even_count_method:
  assumes "vwb_lens i" and "weak_lens a" and "vwb_lens j" and "weak_lens n"
      and "i \<bowtie> a" and "i \<bowtie> j" and "i \<bowtie> n" and "a \<bowtie> j" and "a \<bowtie> n" and "j \<bowtie> n"
  shows
  "\<lbrace>&a =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &n =\<^sub>u 1\<rbrace>
      i :== &a ;; j :== 0 ;;
      (&a =\<^sub>u 0 \<and> &n =\<^sub>u 1 \<and> &j =\<^sub>u 0 \<and> &i =\<^sub>u &a)\<^sup>\<top> ;;
    while &i <\<^sub>u &n
      invr &a =\<^sub>u 0 \<and> &n =\<^sub>u 1 \<and> &j =\<^sub>u (((&i + 1) - &a) div 2) \<and> &i \<le>\<^sub>u &n \<and> &i \<ge>\<^sub>u &a
      do (j :== &j + 1 \<triangleleft> &i mod 2 =\<^sub>u 0 \<triangleright>\<^sub>r II) ;; i :== &i + 1 od
    \<lbrace>&j =\<^sub>u 1\<rbrace>\<^sub>u"
  by (insert assms) vcg

lemma even_count_method_step:
  assumes "vwb_lens i" and "weak_lens a" and "vwb_lens j" and "weak_lens n"
      and "i \<bowtie> a" and "i \<bowtie> j" and "i \<bowtie> n" and "a \<bowtie> j" and "a \<bowtie> n" and "j \<bowtie> n"
  shows
  "\<lbrace>&a =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &n =\<^sub>u 1\<rbrace>
      i :== &a ;; j :== 0 ;;
      (&a =\<^sub>u 0 \<and> &n =\<^sub>u 1 \<and> &j =\<^sub>u 0 \<and> &i =\<^sub>u &a)\<^sup>\<top> ;;
    while &i <\<^sub>u &n
      invr &a =\<^sub>u 0 \<and> &n =\<^sub>u 1 \<and> &j =\<^sub>u (((&i + 1) - &a) div 2) \<and> &i \<le>\<^sub>u &n \<and> &i \<ge>\<^sub>u &a
      do (j :== &j + 1 \<triangleleft> &i mod 2 =\<^sub>u 0 \<triangleright>\<^sub>r II) ;; i :== &i + 1 od
    \<lbrace>&j =\<^sub>u 1\<rbrace>\<^sub>u"
  apply (insert assms)
  apply vcg_step
  defer
  apply (rule seq_hoare_r[of _ _ true])
  apply vcg_step+
  unfolding lens_indep_def
  apply vcg_step+
  using mod_pos_pos_trivial
  apply vcg_step
  apply vcg_step
  apply vcg_step
  apply vcg_step
  apply vcg_step
  (* leaves us with an extra schematic variable *)
  done

lemma increment_manual:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&y =\<^sub>u \<guillemotleft>5::int\<guillemotright>\<rbrace>
    x :== 0;;
   (&x =\<^sub>u 0 \<and> &y =\<^sub>u 5)\<^sup>\<top>;;
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 5\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule seq_hoare_r[of _ _ true])
(*   apply (rule assigns_hoare_r) (* hoare_true works here but not in general *) *)
  defer
  apply (rule seq_hoare_r)
  apply (rule assume_hoare_r)
  apply (rule skip_hoare_r)
  defer
  apply (rule while_invr_hoare_r)
  unfolding lens_indep_def
  apply rel_auto
  apply rel_auto
  apply rel_auto
  apply rel_auto
  apply rel_auto
  done

lemma increment_method:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&y =\<^sub>u \<guillemotleft>5::int\<guillemotright>\<rbrace>
    x :== 0;;
   (&x =\<^sub>u 0 \<and> &y =\<^sub>u 5)\<^sup>\<top>;;
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 5\<rbrace>\<^sub>u"
  by (insert assms) vcg

lemma increment_method_step:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&y =\<^sub>u \<guillemotleft>5::int\<guillemotright>\<rbrace>
    x :== 0;;
   (&x =\<^sub>u 0 \<and> &y =\<^sub>u 5)\<^sup>\<top>;;
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 5\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule seq_hoare_r[of _ _ true])
  unfolding lens_indep_def
  apply vcg_step+
  done

lemma increment'_manual:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 5\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule while_invr_hoare_r)
  unfolding lens_indep_def
  apply rel_auto
  apply rel_auto
  apply rel_auto
  done

lemma increment'_method:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 5\<rbrace>\<^sub>u"
  by (insert assms) vcg

lemma double_increment_manual:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od;;
    (&x =\<^sub>u 5 \<and> &y =\<^sub>u 5)\<^sup>\<top>;;
    while &x <\<^sub>u &y * 2
      invr &x \<le>\<^sub>u &y * 2 \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 10\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule seq_hoare_r[of _ _ true])

  apply (rule while_invr_hoare_r)
  unfolding lens_indep_def
  apply rel_auto
  apply rel_auto
  apply rel_auto

  apply (rule seq_hoare_r)
  apply (rule assume_hoare_r)
  apply (rule skip_hoare_r)
  apply rel_auto

  apply (rule while_invr_hoare_r)
  apply rel_auto
  apply rel_auto
  apply rel_auto
  done

lemma double_increment_method:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od;;
    (&x =\<^sub>u 5 \<and> &y =\<^sub>u 5)\<^sup>\<top>;;
    while &x <\<^sub>u &y * 2
      invr &x \<le>\<^sub>u &y * 2 \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 10\<rbrace>\<^sub>u"
  by (insert assms) vcg

lemma double_increment_method_step:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od;;
    (&x =\<^sub>u 5 \<and> &y =\<^sub>u 5)\<^sup>\<top>;;
    while &x <\<^sub>u &y * 2
      invr &x \<le>\<^sub>u &y * 2 \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x =\<^sub>u 10\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule seq_hoare_r[of _ _ true])
  apply vcg_step+
  unfolding lens_indep_def
  apply vcg_step+
  done

subsubsection \<open>Building more complicated stuff\<close>

lemma if_increment_manual:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<triangleleft> b \<triangleright>\<^sub>r
    while &x <\<^sub>u &y * 2
      invr &x \<le>\<^sub>u &y * 2 \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x \<in>\<^sub>u {5, 10}\<^sub>u\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule cond_hoare_r)
  unfolding lens_indep_def

  apply (rule while_invr_hoare_r)
  apply rel_auto+

  apply (rule while_invr_hoare_r)
  apply rel_auto+
  done

lemma if_increment_method:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<triangleleft> b \<triangleright>\<^sub>r
    while &x <\<^sub>u &y * 2
      invr &x \<le>\<^sub>u &y * 2 \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x \<in>\<^sub>u {5, 10}\<^sub>u\<rbrace>\<^sub>u"
  by (insert assms) vcg

lemma if_increment_method_step:
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows
  "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
    while &x <\<^sub>u &y
      invr &x \<le>\<^sub>u &y \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<triangleleft> b \<triangleright>\<^sub>r
    while &x <\<^sub>u &y * 2
      invr &x \<le>\<^sub>u &y * 2 \<and> &y =\<^sub>u 5
      do x :== &x + 1 od
    \<lbrace>&x \<in>\<^sub>u {5, 10}\<^sub>u\<rbrace>\<^sub>u"
  apply (insert assms)
  apply (rule cond_hoare_r) (* needed as vcg_step tries utp_methods first and that messes up cond
rule *)
  apply vcg_step+
  unfolding lens_indep_def
  apply vcg_step+
  done

section Testing

lemma
  assumes X: "Q \<longrightarrow> P" Q
  shows P
  by (match X in I: "Q \<longrightarrow> P" and I': Q \<Rightarrow> \<open>insert mp[OF I I']\<close>)

lemma "Q \<longrightarrow> P \<Longrightarrow> Q \<Longrightarrow> P"
  by (match premises in I: "Q \<longrightarrow> P" and I': Q \<Rightarrow> \<open>insert mp[OF I I']\<close>)

lemma
  assumes "vwb_lens x" and "x \<bowtie> y"
  shows "\<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
         x :== 3
        \<lbrace>&x =\<^sub>u 3 \<and> &y =\<^sub>u 5\<rbrace>\<^sub>u"
  apply (rule assigns_hoare_r)
  using assms
  apply (match assms in "_ \<bowtie> _" \<Rightarrow> \<open>unfold lens_indep_def\<close>)
  apply rel_auto
  done

lemma
  "vwb_lens x \<Longrightarrow> x \<bowtie> y \<Longrightarrow> \<lbrace>&x =\<^sub>u \<guillemotleft>0::int\<guillemotright> \<and> &y =\<^sub>u 5\<rbrace>
         x :== 3
        \<lbrace>&x =\<^sub>u 3 \<and> &y =\<^sub>u 5\<rbrace>\<^sub>u"
  apply (rule assigns_hoare_r)
  apply (match conclusion in _ \<Rightarrow> \<open>unfold lens_indep_def\<close>) (* why doesn't premises work? *)
  apply rel_auto
  done

end
