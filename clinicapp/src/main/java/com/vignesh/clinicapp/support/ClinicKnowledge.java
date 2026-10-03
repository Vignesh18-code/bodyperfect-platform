package com.vignesh.clinicapp.support;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import java.text.Normalizer;
import java.util.*;
import java.util.stream.Collectors;

/** Versioned public website snapshot. Retrieval never follows user-supplied URLs. */
@Component
public class ClinicKnowledge {
 public record Source(String id,String title,String url,String retrievedAt,String text) {}
 private record Chunk(Source source,Map<String,Long> terms,int length) {}
 private final List<Chunk> chunks;
 private final Map<String,Integer> frequency=new HashMap<>();
 private final int pages;
 private final String updated;
 private final Source serviceDirectory;
 private static final Set<String> STOP=Set.of("the","a","an","is","are","and","or","to","of","for","i","my","me","you","your","in","at","it","with","what","can","do","does","how","about","please","tell","this","that","on","be","have","we","our","bodyperfect","body","perfect");
 public ClinicKnowledge(ObjectMapper json)throws Exception {
  List<Map<String,String>> docs=json.readValue(new ClassPathResource("knowledge/bodyperfect.json").getInputStream(),new TypeReference<>(){});
  pages=docs.size();updated=docs.isEmpty()?"":docs.getFirst().get("retrievedAt");
  serviceDirectory=json.readValue(new ClassPathResource("knowledge/bodyperfect-services.json").getInputStream(),Source.class);
  var built=new ArrayList<Chunk>();
  for(var d:docs){
   String body=d.get("text");
   if(!d.get("url").startsWith("https://www.bodyperfect.ae/"))throw new IllegalArgumentException("Invalid knowledge source");
   for(int start=0,part=0;start<body.length();start+=1050,part++){
    String text=body.substring(start,Math.min(start+1250,body.length()));
    var source=new Source(d.get("id")+"-"+part,d.get("title"),d.get("url"),d.get("retrievedAt"),text);
    var terms=tokens(d.get("title")+" "+d.get("title")+" "+text).stream().collect(Collectors.groupingBy(t->t,Collectors.counting()));
    built.add(new Chunk(source,terms,terms.values().stream().mapToInt(Long::intValue).sum()));
    for(String token:terms.keySet())frequency.merge(token,1,Integer::sum);
   }
  }
  chunks=List.copyOf(built);
 }
 public int pages(){return pages;}
 public String updated(){return updated;}
 static List<String> tokens(String text){
  return Arrays.stream(Normalizer.normalize(text,Normalizer.Form.NFKD).replaceAll("\\p{M}","").toLowerCase(Locale.ROOT).split("[^\\p{L}\\p{N}]+"))
   .filter(t->!t.isBlank()&&!STOP.contains(t)).toList();
 }
 public List<Source> search(String question){
  String q=question.toLowerCase(Locale.ROOT);
  if(isDirectoryQuery(q))return List.of(new Source("S1",serviceDirectory.title,serviceDirectory.url,serviceDirectory.retrievedAt,serviceDirectory.text));
  if(q.matches(".*\\b(hours|opening|location|address|phone|contact|branch|marina|burjuman|fujairah)\\b.*"))q+=" contact clinic";
  if(q.contains("gym"))q+=" personal training";
  if(q.contains("lose weight"))q+=" weightloss slimming";
  var terms=new HashSet<>(tokens(q));
  record Scored(Chunk chunk,double score){}
  var ranked=chunks.stream().map(c->{double score=0;for(var t:terms){double tf=c.terms.getOrDefault(t,0L);if(tf==0)continue;double idf=Math.log(1+(chunks.size()-frequency.getOrDefault(t,0)+.5)/(frequency.getOrDefault(t,0)+.5));score+=idf*tf*2.2/(tf+1.2*(.25+.75*c.length/220.0));}return new Scored(c,score);})
   .filter(s->s.score>0).sorted(Comparator.comparingDouble(Scored::score).reversed()).toList();
  var counts=new HashMap<String,Integer>();var result=new ArrayList<Source>();
  for(var s:ranked){var src=s.chunk.source;if(counts.getOrDefault(src.url,0)>=2)continue;counts.merge(src.url,1,Integer::sum);result.add(new Source("S"+(result.size()+1),src.title,src.url,src.retrievedAt,src.text));if(result.size()==6)break;}
  return List.copyOf(result);
 }
 static boolean isDirectoryQuery(String question){
  String q=question.toLowerCase(Locale.ROOT);
  return q.contains("available treatments") || q.contains("what services") || q.contains("services do you offer") ||
   (q.matches("(?s).*\\b(services?|treatments?|offerings)\\b.*") && q.matches("(?s).*\\b(list|categories|category|all|offer)\\b.*"));
 }
}
