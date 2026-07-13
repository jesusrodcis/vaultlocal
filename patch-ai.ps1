# patch-ai.ps1 — injects the AI tool-calling layer directly into index.html
$ErrorActionPreference = 'Stop'
$file = "C:\Users\jesus\Documents\Development\vault\index.html"

Copy-Item $file "$file.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Backup created."

$html = Get-Content $file -Raw

# Remove the broken external script tag if present
if ($html -match '<script src="ai-tools\.js"></script>\s*') {
    $html = $html -replace '<script src="ai-tools\.js"></script>\s*', ''
    Write-Host "Removed broken ai-tools.js tag."
}

# The tool layer JS (injected before the LAST </script>)
$toolJs = @'
// === AI TOOL-CALLING LAYER ===
const AI_TOOLS = [
  { name:"get_safe_to_spend", description:"Bank balance minus all unpaid scheduled DDs due before next payday. Survival buffer; variable spend excluded.", input_schema:{type:"object",properties:{}} },
  { name:"get_balances", description:"Balance per bank (PTSB, BoI, Revolut) and total.", input_schema:{type:"object",properties:{}} },
  { name:"get_income_and_payday", description:"Monthly net income and expected payday day-of-month.", input_schema:{type:"object",properties:{}} },
  { name:"get_direct_debits", description:"All DDs: name, amount, dayOfMonth, bank or unassigned, paid, period this/next, salary-covered.", input_schema:{type:"object",properties:{}} },
  { name:"get_debts", description:"Loans and credit cards: balance, APR, monthly payment, limit, due day.", input_schema:{type:"object",properties:{}} },
  { name:"get_monthly_budget", description:"Disposable = income - committed DDs - variable budget. Use for how-much-can-I-save.", input_schema:{type:"object",properties:{}} },
  { name:"get_spending_by_category", description:"Spend per category over last N months.", input_schema:{type:"object",properties:{months:{type:"number"}}} },
  { name:"search_transactions", description:"Search past transactions by keyword e.g. brunch. Returns matches, total, average.", input_schema:{type:"object",properties:{query:{type:"string"},months:{type:"number"}},required:["query"]} },
  { name:"get_goals", description:"Savings goals/sinking funds: pre-orders, planned purchases, overpayment targets.", input_schema:{type:"object",properties:{}} }
];

async function runAITool(name, input){
  input = input || {};
  try {
    if(name==='get_safe_to_spend'){
      const b=await getAllBalances(); const total=Object.values(b).reduce((a,v)=>a+(parseFloat(v)||0),0);
      const dds=window._classifiedDDs||[]; const pend=dds.filter(d=>d.countsAgainstBalance);
      const pt=pend.reduce((a,d)=>a+d.amount,0);
      return {safeToSpend:+(total-pt).toFixed(2),totalBalance:+total.toFixed(2),pendingBeforePayday:+pt.toFixed(2),
        pendingItems:pend.map(d=>({name:d.name,amount:d.amount,day:d.dayOfMonth,bank:d.bank||'unassigned',daysUntil:d.daysUntil})),
        note:"Balance minus unpaid DDs before payday. Variable excluded. Do not spend below this."};
    }
    if(name==='get_balances'){const b=await getAllBalances();const L={ptsb:'PTSB',boi:'Bank of Ireland',revolut:'Revolut'};
      return {balances:Object.entries(b).map(([k,v])=>({bank:L[k]||k,balance:+(parseFloat(v)||0).toFixed(2)})),total:+Object.values(b).reduce((a,v)=>a+(parseFloat(v)||0),0).toFixed(2)};}
    if(name==='get_income_and_payday'){const n=new Date();const p=await expectedPayday(n.getFullYear(),n.getMonth());
      return {monthlyNetIncome:getMonthlyIncome()||0,expectedPaydayDayOfMonth:p};}
    if(name==='get_direct_debits'){const dds=window._classifiedDDs||[];const L={ptsb:'PTSB',boi:'BoI',revolut:'Revolut'};
      return {directDebits:dds.map(d=>({name:d.name,amount:d.amount,dayOfMonth:d.dayOfMonth,bank:d.bank?(L[d.bank]||d.bank):'unassigned',
        paid:!!d.paid,period:d.dueThisMonth?'this':'next',coveredBySalary:d.isPostPayday&&d.salaryEffectivelyHere,
        paused:!!d._paused,frequency:d.frequency===0?'weekly':(d.frequency||1)+'-monthly'}))};}
    if(name==='get_debts'){const dt=await dbGetAll('debts');
      return {debts:dt.map(d=>({name:d.name,type:d.type,balance:d.balance,apr:d.rate,monthlyPayment:d.monthlyPayment||0,limit:d.limit||null,dueDay:d.dueDayOfMonth||null}))};}
    if(name==='get_monthly_budget'){const inc=getMonthlyIncome()||0;const dds=window._classifiedDDs||[];
      const c=dds.filter(d=>!d._paused&&d.active&&!d._deleted);
      const tDD=c.reduce((a,d)=>d.frequency===0?a+d.amount*52/12:a+d.amount/(d.frequency||1),0);
      const tV=(getBudgetCats()||[]).reduce((a,c)=>a+(c.amount||0),0);
      return {monthlyIncome:+inc.toFixed(2),committedDirectDebits:+tDD.toFixed(2),variableBudget:+tV.toFixed(2),disposableToSave:+(inc-tDD-tV).toFixed(2),note:"disposableToSave=income-DDs-variable. Use for savings questions."};}
    if(name==='get_spending_by_category'){const m=input.months||3;const tx=await dbGetAll('transactions');
      const co=new Date();co.setMonth(co.getMonth()-m);const cs=co.toISOString().slice(0,10);const bc={};
      tx.filter(t=>!t.isCredit&&!t.isInternal&&t.date>=cs).forEach(t=>{bc[t.category||'Unknown']=(bc[t.category||'Unknown']||0)+t.amount;});
      return {months:m,byCategory:Object.entries(bc).sort((a,b)=>b[1]-a[1]).map(([c,t])=>({category:c,total:+t.toFixed(2),perMonth:+(t/m).toFixed(2)}))};}
    if(name==='search_transactions'){const q=(input.query||'').toLowerCase();const m=input.months||6;const tx=await dbGetAll('transactions');
      const co=new Date();co.setMonth(co.getMonth()-m);const cs=co.toISOString().slice(0,10);
      const mt=tx.filter(t=>!t.isInternal&&t.date>=cs&&((t.description||'').toLowerCase().includes(q)||(t.category||'').toLowerCase().includes(q)));
      const tot=mt.reduce((a,t)=>a+t.amount,0);
      return {query:input.query,monthsSearched:m,count:mt.length,totalSpent:+tot.toFixed(2),average:mt.length?+(tot/mt.length).toFixed(2):0,
        transactions:mt.slice(0,25).map(t=>({date:t.date,description:t.description,amount:t.amount,category:t.category}))};}
    if(name==='get_goals'){let g=[];try{g=await dbGetAll('goals');}catch(e){}
      return {goals:g.map(x=>({name:x.name,type:x.type,target:x.targetAmount,targetDate:x.targetDate||null,saved:x.savedSoFar||0,monthlyContribution:x.monthlyContribution||0}))};}
    return {error:"Unknown tool: "+name};
  }catch(err){return {error:err.message};}
}

function buildToolSystemPrompt(){
  const now=new Date();
  return "You are VaultLocal AI, a private financial assistant. Data is local. Use euro. Be concise. Today is "+now.toLocaleDateString('en-IE',{weekday:'long',day:'numeric',month:'long',year:'numeric'})+".\n\n"+
"You have TOOLS for the user's real financial data. ALWAYS call the relevant tool before answering. NEVER guess numbers.\n\n"+
"LOGIC:\n"+
"1. get_safe_to_spend = balance minus unpaid DDs before payday (survival buffer). If low, advise AGAINST brunch/pre-orders; protect commitments first. e.g. 1000 balance - 900 DDs = 100 safe -> say no to extras.\n"+
"2. 'How much can I save?' -> use get_monthly_budget disposableToSave, NOT safe-to-spend.\n"+
"3. 'Can I afford X based on history?' -> use search_transactions.\n"+
"4. 'Which bank is this DD?' -> get_direct_debits; say 'not assigned' if unassigned.\n"+
"5. 'This period or next?' -> use the period field from get_direct_debits.\n"+
"6. Surplus allocation priority: fund goals/pre-orders due soonest, then planned purchases, then overpay highest-APR loan.";
}

async function callBedrockChatWithTools(history){
  const url=(localStorage.getItem('bedrock_proxy_url')||'').trim();
  const key=(localStorage.getItem('bedrock_api_key')||'').trim();
  if(!url) return "Bedrock proxy URL not configured.";
  let messages=history.map(m=>({role:m.role==='assistant'?'assistant':'user',content:m.content}));
  const system=buildToolSystemPrompt();
  for(let turn=0;turn<6;turn++){
    const res=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json',...(key?{'x-api-key':key}:{})},
      body:JSON.stringify({messages,system,tools:AI_TOOLS,max_tokens:4096})});
    if(!res.ok){const t=await res.text();return "AI error: "+res.status+" "+t;}
    const data=await res.json();
    const content=data.content||[];
    const toolUses=content.filter(c=>c.type==='tool_use');
    if(toolUses.length===0){
      const txt=content.filter(c=>c.type==='text').map(c=>c.text).join('\n');
      return txt||"(no response)";
    }
    messages.push({role:'assistant',content});
    const results=[];
    for(const tu of toolUses){
      const out=await runAITool(tu.name,tu.input);
      console.log('[tool]',tu.name,tu