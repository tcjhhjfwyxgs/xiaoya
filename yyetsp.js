var rule = {
	title:'人人影视[搜]',
	host:'http://127.0.0.1:10079',
	homeUrl:'/p/0/socks5:%252F%252F192.168.101.1:1080/https://yyets.click/',
	url:'*',
	filter_url:'{{fl.class}}',
	filter:{
	},
	searchUrl: '*',
	searchable:2,
	quickSearch:0,
	filterable:0,
	headers:{
		'User-Agent': PC_UA,
		'Accept': '*/*',
		'Referer': 'https://yyets.click/','cookie':'ctoken=kb25Pl4vAtN6nCToXMhUp56m; b-user-id=8d154efc-efef-2056-600c-396612b2ab67; _UP_A4A_11_=wb9041a5b640467eade205aac0935d44; _UP_D_=pc; __wpkreporterwid_=47234f73-bb77-4a9d-3c6d-32170a091451; _UP_F7E_8D_=ZZgJ7pUw4GlKvHo1WSCSRxzy6ZfcuPaCcCX5PS4jd7ZM7G5rLtmiOSwgG3mCnckgEUez5D%2BmyE8HjaM3L9JAQJQdokMYch13ywfi%2FNw59JSA4d%2BoZ0XH5Vv0CWFeDTU7Ougq3xTtGiRrC2zMTJ%2BWmi2z3qDnYStBfuAlccHfgOZMnJVud4XLkzptKiV3q7grD3oTXTZApNHfBrxPIPWYXd57eBgSPh1CeNyRfMd3E%2FaCJwsZdYNQtLNWMS8ybOdpVnaCJNfZ71n8rT%2FNXCSsX79Rn8AU60dG0vwRrfdXxoWTMMmbzim1P%2FGZG4Kxr5sMas4r5bs16kB65h1MGsfX1ZXMxBnUatpyZEouei4Mg616bMmHRmANBeAo%2F57a%2FNL5FE3GuRNC6i3ARLeFDeow2A%3D%3D; _UP_30C_6A_=st9046201dbbstq552fvz56a8okoyglo; _UP_TS_=sg1b38873510634273e65b4f0453aa607db; _UP_E37_B7_=sg1b38873510634273e65b4f0453aa607db; _UP_TG_=st9046201dbbstq552fvz56a8okoyglo; _UP_335_2B_=1; __pus=4c906aeb42b9d78362fd67837239f09fAAQYgFq9eKzZMz1jqUSR5qOFqazqW1NYPMOzVCZVPVsmlcasFBvlPDsiZ9I5vhTOMNrRDbheGkOc5YQIdY+qa5LA; __kp=c0c9c050-45a2-11ee-a6cf-83a59d295b06; __kps=AASVSpdSgOZMapUyMnfOgG3z; __ktd=DJUlw7AcCYNDqz2ynLofhA==; __uid=AASVSpdSgOZMapUyMnfOgG3z; __itrace_wid=7be9d92c-b503-48f8-818a-391f7d2eb736; __puus=7d977aaf24d62da4d9ad088e4c6bec4bAASP6/MhOSx3stWLygkqjUAmPP+p4qCkbF1IwGa0MiWyBYKcftBVbnSOcyxDxMuzoV3csrxTcHZE28ldZG0AAN/+A8NLswIDjCp5qXvHoBV+q4wIXuG1grg1uH/VrPtBs2Z5MH9Wkcpod5d+9rA2atye45nZ5lpnof798AfVFfYx8Vhrye7JfNHjw28lBes2WUypdcIe3e90/bWzKHcwLrFU'
},
	
	timeout:5000,
	class_name:'',
	class_url:'',
	play_parse:true,
	play_json:[{
		re:'*',
		json:{
			parse:0,
			jx:0
		}
	}],
	lazy:'',
	limit:6,
	推荐:'',
	一级:'',
	二级:`js:
VOD.vod_play_from = "雲盤";
VOD.vod_remarks = detailUrl;
VOD.vod_actor = "沒有二級，只有一級鏈接直接推送播放";
VOD.vod_content = MY_URL;
VOD.vod_play_url = "雲盤$" + detailUrl;
`,
	搜索:`js:
let new_html=request(rule.homeUrl + 'api/resource?keyword=' + encodeURIComponent(KEY) + '&type=default');
log("yyets search result>>>>>>>>>>>>>>>" + new_html);
let json=JSON.parse(new_html);
let d=[];
for(const it in json.comment){
	if (json.comment.hasOwnProperty(it)){
		log("yyets search it>>>>>>>>>>>>>>>" + JSON.stringify(json.comment[it]));
		if (/(www.aliyundrive.com|pan.quark.cn)/.test(json.comment[it].comment)){
			let its = json.comment[it].comment.split("\\n");
			let i=0;
			while(i<its.length){
				let title=its[i].trim().replaceAll(/\\s+/g," ");
				if (title.length==0){
					i++;
					continue;
				}
				let urls=[];
				log("yyets search title>>>>>>>>>>>>>>>" + title);
				while(++i<its.length){
					log("yyets search url>>>>>>>>>>>>>>>" + its[i]);
					let burl = its[i].trim().split(" ")[0];
					if (burl.length==0){
						continue;
					}
					if (burl.includes("https://")){
						urls.push("https:"+burl.split("https:")[1]);
					}else{
						break;
					}
				}
				if (urls.length>0){
					log("yyets search title,urls>>>>>>>>>>>>>>>" + title + ",[" + JSON.stringify(urls) + "]");
					if (title.includes(KEY)){
						urls.forEach(function (url) {
							d.push({
								title:title,
								img:'',
								content:json.comment[it].comment,
								desc:json.comment[it].date,
								url:'push://'+url
								});
						});
					}
				}
			}
		}
	}
}
setResult(d);
`,
}
