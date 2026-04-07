import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Difficulty = "easy" | "medium" | "hard";
type QuestionStyle =
  | "standard"
  | "new_generation"
  | "short_drill"
  | "long_paragraph"
  | "table_interpretation"
  | "graph_interpretation";

type GeneratedQuestion = {
  question_text: string;
  option_a: string;
  option_b: string;
  option_c: string;
  option_d: string;
  option_e?: string;
  correct_answer: "A" | "B" | "C" | "D" | "E";
  difficulty?: Difficulty;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = mustEnv("SUPABASE_URL");
    const serviceRoleKey = mustEnv("SUPABASE_SERVICE_ROLE_KEY");
    const googleApiKey = mustEnv("GOOGLE_API_KEY");
    const googleModel = Deno.env.get("GOOGLE_MODEL") ?? "gemini-2.5-flash";
    const rawGoogleApiBaseUrl =
      Deno.env.get("GOOGLE_API_BASE_URL") ??
      "https://generativelanguage.googleapis.com/v1beta";
    const googleApiBaseUrl = normalizeGoogleApiBaseUrl(rawGoogleApiBaseUrl);

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const authHeader = request.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "").trim();

    let createdBy: string | null = null;
    if (token) {
      const userClient = createClient(
        supabaseUrl,
        Deno.env.get("SUPABASE_ANON_KEY") ?? mustEnv("SUPABASE_ANON_KEY"),
        {
          global: {
            headers: { Authorization: `Bearer ${token}` },
          },
          auth: { persistSession: false },
        },
      );
      const { data: userData } = await userClient.auth.getUser();
      createdBy = userData.user?.id ?? null;
    }

    const body = await request.json();
    const examId = requiredString(body.exam_id, "exam_id");
    const subjectId = requiredString(body.subject_id, "subject_id");
    const topicId = requiredString(body.topic_id, "topic_id");
    const difficulty = asDifficulty(body.difficulty);
    const questionStyle = asQuestionStyle(body.question_style);
    const measurementFocus = requiredString(
      body.measurement_focus,
      "measurement_focus",
    );
    const targetCount = asPositiveInt(body.target_count, 1, 25);
    const batchSize = asPositiveInt(body.batch_size ?? targetCount, 1, 25);

    const { data: examRow, error: examError } = await supabase
      .from("exams")
      .select("id, name")
      .eq("id", examId)
      .single();
    if (examError || !examRow) {
      throw new Error("Sınav kaydı bulunamadı.");
    }

    const { data: subjectRow, error: subjectError } = await supabase
      .from("subjects")
      .select("id, name, section_name")
      .eq("id", subjectId)
      .single();
    if (subjectError || !subjectRow) {
      throw new Error("Ders kaydı bulunamadı.");
    }

    const { data: topicRow, error: topicError } = await supabase
      .from("topics")
      .select("id, name, section_name")
      .eq("id", topicId)
      .single();
    if (topicError || !topicRow) {
      throw new Error("Konu kaydı bulunamadı.");
    }

    const { data: jobRow, error: jobInsertError } = await supabase
      .from("question_generation_jobs")
      .insert({
        exam_id: examId,
        subject_id: subjectId,
        topic_id: topicId,
        section_name: topicRow.section_name ?? subjectRow.section_name,
        difficulty,
        question_style: questionStyle,
        target_count: targetCount,
        batch_size: batchSize,
        generated_count: 0,
        inserted_count: 0,
        duplicate_count: 0,
        failed_count: 0,
        status: "running",
        prompt_version: "gemini-v2",
        notes: measurementFocus,
        created_by: createdBy,
        started_at: new Date().toISOString(),
      })
      .select("id")
      .single();

    if (jobInsertError || !jobRow) {
      throw new Error("Üretim işi başlatılamadı.");
    }

    const jobId = jobRow.id as string;

    try {
      const existingRows = await supabase
        .from("questions")
        .select("normalized_stem")
        .eq("exam_id", examId)
        .eq("subject_id", subjectId)
        .eq("topic_id", topicId)
        .not("normalized_stem", "is", null)
        .limit(250);

      const existingNormalized = new Set<string>(
        (existingRows.data ?? [])
          .map((row) => String(row.normalized_stem ?? "").trim())
          .filter((value) => value.length > 0),
      );

      const roleInstructions = buildRoleInstructions(examRow.name);
      const styleInstructions = buildStyleInstructions(questionStyle);
      const difficultyInstructions = buildDifficultyInstructions(difficulty);
      const topicInstructions = buildTopicInstructionsV2({
        examName: examRow.name,
        subjectName: subjectRow.name,
        topicName: topicRow.name,
        questionStyle,
      });
      const prompt = buildPromptV2({
        examName: examRow.name,
        subjectName: subjectRow.name,
        topicName: topicRow.name,
        difficulty,
        questionStyle,
        measurementFocus,
        roleInstructions,
        styleInstructions,
        difficultyInstructions,
        topicInstructions,
        count: targetCount,
      });

      const aiQuestions = await generateQuestionsWithGemini({
        prompt,
        apiKey: googleApiKey,
        model: googleModel,
        baseUrl: googleApiBaseUrl,
      });

      let generatedCount = 0;
      let insertedCount = 0;
      let duplicateCount = 0;
      let failedCount = 0;
      const insertedQuestions: Array<Record<string, unknown>> = [];

      for (const candidate of aiQuestions.slice(0, targetCount)) {
        generatedCount += 1;

        try {
          const normalized = normalizeStem(candidate.question_text);
          if (!normalized) {
            failedCount += 1;
            continue;
          }

          if (existingNormalized.has(normalized)) {
            duplicateCount += 1;
            continue;
          }

          const questionPayload = {
            exam_id: examId,
            subject_id: subjectId,
            topic_id: topicId,
            question_text: candidate.question_text.trim(),
            option_a: candidate.option_a.trim(),
            option_b: candidate.option_b.trim(),
            option_c: candidate.option_c.trim(),
            option_d: candidate.option_d.trim(),
            option_e: (candidate.option_e ?? "").trim() || null,
            correct_answer: candidate.correct_answer,
            difficulty: candidate.difficulty ?? difficulty,
            normalized_stem: normalized,
            is_verified: false,
            verified_by: null,
            verified_at: null,
            source: "ai_generated",
            generation_job_id: jobId,
            measurement_focus: measurementFocus,
          };

          const { data: insertedQuestion, error: insertedQuestionError } =
            await supabase
              .from("questions")
              .insert(questionPayload)
              .select(
                "id, question_text, option_a, option_b, option_c, option_d, option_e, correct_answer, difficulty",
              )
              .single();

          if (insertedQuestionError || !insertedQuestion) {
            failedCount += 1;
            continue;
          }

          const options = buildOptions(insertedQuestion.id as string, candidate);
          const { error: optionsError } = await supabase
            .from("question_options")
            .insert(options);

          if (optionsError) {
            await supabase
              .from("questions")
              .delete()
              .eq("id", insertedQuestion.id);
            failedCount += 1;
            continue;
          }

          existingNormalized.add(normalized);
          insertedCount += 1;
          insertedQuestions.push(insertedQuestion);
        } catch {
          failedCount += 1;
        }
      }

      const status = insertedCount === targetCount
        ? "completed"
        : insertedCount > 0
        ? "partially_completed"
        : "failed";

      await supabase
        .from("question_generation_jobs")
        .update({
          generated_count: generatedCount,
          inserted_count: insertedCount,
          duplicate_count: duplicateCount,
          failed_count: failedCount,
          status,
          completed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", jobId);

      return jsonResponse({
        success: insertedCount > 0,
        job_id: jobId,
        generated_count: generatedCount,
        inserted_count: insertedCount,
        duplicate_count: duplicateCount,
        failed_count: failedCount,
        inserted_questions: insertedQuestions,
        prompt_preview: prompt.slice(0, 1200),
      });
    } catch (error) {
      await supabase
        .from("question_generation_jobs")
        .update({
          status: "failed",
          last_error: error instanceof Error ? error.message : String(error),
          completed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", jobId);

      throw error;
    }
  } catch (error) {
    return jsonResponse(
      {
        success: false,
        error: error instanceof Error ? error.message : String(error),
      },
      400,
    );
  }
});

function buildPrompt(input: {
  examName: string;
  subjectName: string;
  topicName: string;
  difficulty: Difficulty;
  questionStyle: QuestionStyle;
  measurementFocus: string;
  roleInstructions: string;
  topicInstructions: string;
  count: number;
}) {
  return `Sen Türkiye'deki öğrencilere yönelik özgün çoktan seçmeli soru üreten deneyimli bir ölçme değerlendirme uzmanısın.

ROL VE STİL:
${input.roleInstructions}

ÖNEMLİ KURALLAR:
- Mevcut yayınlardan, denemelerden, kitaplardan veya gerçek sınavlardan cümle kopyalama.
- Telifli içerikleri yeniden yazma, taklit etme veya çok yakın varyasyon üretme.
- Sadece konu bilgisinden hareketle sıfırdan özgün soru üret.
- Sorular Türkçe olsun.
- Müfredata ve öğrenci seviyesine uygun olsun.
- Her soruda yalnızca bir doğru cevap bulunsun.
- Sorular açıklama değil, doğrudan sınav sorusu formatında olsun.
- Her soru açık ve tamamlanmış bir soru kökü içersin.
- Her soru tam olarak 5 şıklı olsun: A, B, C, D, E.
- Şıkların hepsi anlamlı ve birbirinden ayırt edilebilir olsun.
- Şıklar dengeli uzunlukta olsun, doğru cevap ipucu vermesin.
- Ölçülmek istenen kazanım veya beceri soru kökünde açıkça hissedilsin.
- Tek cümlelik yüzeysel soru üretme.
- Soru kökünü ve bağlamını daha detaylı, daha uzun ve öğrencinin gerçekten düşünmesini gerektirecek biçimde kur.

ÜRETİM BAĞLAMI:
- Sınav: ${input.examName}
- Ders: ${input.subjectName}
- Konu: ${input.topicName}
- Ölçülmek istenen kazanım / beceri: ${input.measurementFocus}
- Zorluk: ${input.difficulty}
- Soru stili: ${input.questionStyle}
- Adet: ${input.count}

KONUYA ÖZEL TALİMATLAR:
${input.topicInstructions}

STİL AÇIKLAMASI:
- standard: klasik çoktan seçmeli soru
- new_generation: yorum ve akıl yürütme ağırlıklı
- short_drill: kısa ve hızlı tekrar sorusu
- long_paragraph: daha uzun metinli soru
- table_interpretation: tablo yorumlamalı
- graph_interpretation: grafik yorumlamalı

ÇIKTI KURALI:
- Yalnızca geçerli JSON döndür.
- Markdown kullanma.
- Açıklama yazma.
- Her soru için correct_answer alanı zorunludur.
- correct_answer yalnızca A, B, C, D veya E olabilir.
- Her soruda tek bir doğru cevap üret.
- Doğru cevap, hesap veya kavramsal gerekçeyle savunulabilir olsun.
- JSON şeması tam olarak şu olsun:
{
  "questions": [
    {
      "question_text": "...",
      "option_a": "...",
      "option_b": "...",
      "option_c": "...",
      "option_d": "...",
      "option_e": "...",
      "correct_answer": "A",
      "difficulty": "${input.difficulty}"
    }
  ]
}`;
}

function buildRoleInstructions(examName: string) {
  const normalized = examName.trim().toUpperCase();

  if (normalized === "YKS") {
    return `- YKS için çalışan deneyimli bir lise branş öğretmeni gibi davran.
- Sorular TYT veya AYT öğrenci seviyesine uygun olsun.
- Ezber değil, kavram, yorum ve işlem dengesini birlikte ölç.
- Yeni nesil sorularda gereksiz paragraf şişirmesi yapma; ölçülen beceri net olsun.`;
  }

  if (normalized === "LGS") {
    return `- LGS için çalışan deneyimli bir ortaokul branş öğretmeni gibi davran.
- Dil sade, temiz ve öğrenciyi korkutmayacak kadar anlaşılır olsun.
- Öğrencinin yaş düzeyine uygun günlük bağlamlar kullan.
- Sorular kısa ama düşündürücü olsun.`;
  }

  if (normalized === "KPSS") {
    return `- KPSS için soru hazırlayan bir alan uzmanı gibi davran.
- Soru dili resmi, açık ve ölçme amacı net olsun.
- Bilgi ile yorum dengesini koru.
- Kamu sınavı ciddiyetine uygun bir ölçme dili kullan.`;
  }

  if (normalized === "ALES") {
    return `- ALES için soru hazırlayan akademik ölçme uzmanı gibi davran.
- Sözel veya sayısal akıl yürütmeyi öne çıkar.
- Çeldiriciler güçlü ama adil olsun.
- Zihinsel işlem basamağı belirgin ve temiz olsun.`;
  }

  return `- İlgili sınav için çalışan deneyimli bir branş öğretmeni gibi davran.
- Öğrenci seviyesine uygun, açık ve ölçme amacı net sorular üret.
- Soru, konu ve kazanım uyumu güçlü olsun.`;
}

function buildTopicInstructions(input: {
  examName: string;
  subjectName: string;
  topicName: string;
}) {
  const subject = input.subjectName.trim().toLocaleLowerCase("tr-TR");
  const topic = input.topicName.trim().toLocaleLowerCase("tr-TR");

  if (subject.includes("türkçe") && topic.includes("sözcükte anlam")) {
    return `- Sorular kısa bir bağlam, paragraf veya birden fazla cümle içeren anlamlı bir metin üzerinden kurulmalı.
- Tek bir kelimenin cümle içindeki anlamını, mecaz-gerçek anlam ayrımını, bağlama göre kazandığı anlamı veya anlam kaymasını gerçekten ölçmeli.
- Soru kökü açık olmalı; öğrenciden tam olarak ne istendiği ilk okumada anlaşılmalı.
- "Bu parçada altı çizili söz" ya da benzeri yapı kullanılıyorsa, altı çizili ifadenin hangi anlamda kullanıldığı net biçimde sorulmalı.
- Şıklar birbirine yakın ama ayırt edilebilir anlam seçenekleri sunmalı.
- Doğru cevap yalnızca bir tane olmalı; çeldiriciler sözlüğün en yaygın anlamına ya da yakın anlamlara yaslanabilir ama belirsiz olmamalı.
- Soru metni tek cümlelik olmasın; öğrencinin bağlamdan anlam çıkaracağı kadar detaylı olsun.`;
  }

  if (
    subject.includes("kimya") ||
    subject.includes("fizik") ||
    subject.includes("matematik") ||
    subject.includes("biyoloji")
  ) {
    return `- Sorular hesap, yorum veya kavramsal çözüm gerektirmeli.
- Her soruda yalnızca bir doğru cevap olmalı.
- Doğru cevap açık biçimde A, B, C, D veya E harflerinden biriyle verilmelidir.
- Şıklar birbirine karışmayacak kadar net, ama çeldirici olacak kadar yakın olmalı.
- Doğru seçenek, hesaplama ya da kavramsal çıkarımla savunulabilir olmalı.
- Sayısal ders mantığına uygun olarak belirsiz ve yoruma açık şık üretme.`;
  }

  return `- Soru, ${input.subjectName} dersi ve ${input.topicName} konusu için gerçekten ölçücü olsun.
- Kısa ve yüzeysel soru yerine bağlamı güçlü, açık köklü ve 5 şıklı sorular üret.
- Öğrencinin ezber değil, anlama ve ayırt etme becerisini ölç.`;
}

function buildPromptV2(input: {
  examName: string;
  subjectName: string;
  topicName: string;
  difficulty: Difficulty;
  questionStyle: QuestionStyle;
  measurementFocus: string;
  roleInstructions: string;
  styleInstructions: string;
  difficultyInstructions: string;
  topicInstructions: string;
  count: number;
}) {
  return `Sen Türkiye'deki öğrenciler için özgün, kaliteli, zorlayıcı ve öğretici çoktan seçmeli sorular üreten deneyimli bir ölçme değerlendirme uzmanısın.

ROL:
${input.roleInstructions}

STİL TALİMATLARI:
${input.styleInstructions}

ZORLUK TALİMATLARI:
${input.difficultyInstructions}

KONU TALİMATLARI:
${input.topicInstructions}

GENEL KURALLAR:
- Mevcut yayınlardan, denemelerden, kitaplardan veya gerçek sınavlardan cümle kopyalama.
- Telifli içerikleri yeniden yazma, taklit etme veya çok yakın varyasyon üretme.
- Sadece konu bilgisinden hareketle sıfırdan özgün soru üret.
- Sorular Türkçe olsun.
- Müfredata ve öğrenci seviyesine uygun olsun.
- Her soruda yalnızca bir doğru cevap bulunsun.
- Her soru açık, tamamlanmış ve ne istediği net anlaşılan bir soru kökü içersin.
- Her soru tam olarak 5 şıklı olsun: A, B, C, D, E.
- Şıkların hepsi anlamlı, birbirinden ayırt edilebilir ve çeldirici nitelikte olsun.
- Şıklar doğru cevabı ele vermesin.
- Ölçülmek istenen kazanım soru kökünde ve çözüm mantığında açıkça hissedilsin.
- Tek cümlelik, yüzeysel, kısa ve ezber ağırlıklı soru üretme.
- Mümkün olduğunca soru kökünü bağlamlı, çok adımlı düşünmeye açık ve öğrenciyi gerçekten zorlayacak biçimde kur.
- Sorular öğretici olsun; çözen öğrenci doğru cevaba ulaşırken kavramı pekiştirsin.

ÜRETİM BAĞLAMI:
- Sınav: ${input.examName}
- Ders: ${input.subjectName}
- Konu: ${input.topicName}
- Ölçülmek istenen kazanım / beceri: ${input.measurementFocus}
- Zorluk: ${input.difficulty}
- Soru stili: ${input.questionStyle}
- Adet: ${input.count}

STİL TANIMLARI:
- standard: klasik ama kaliteli, net köklü, öğretici ve çeldiricileri güçlü soru
- new_generation: gerçek yaşam bağlamı, çok adımlı düşünme, yorumlama ve kavram transferi isteyen soru
- short_drill: kısa köklü ama ölçücü, hızlı tekrar sorusu
- long_paragraph: daha uzun metin veya bağlam içeren soru
- table_interpretation: tablo verisi yorumlatan soru
- graph_interpretation: grafik veya değişim ilişkisi yorumlatan soru

ÇIKTI KURALLARI:
- Yalnızca geçerli JSON döndür.
- Markdown kullanma.
- Açıklama yazma.
- Her soru için correct_answer alanı zorunludur.
- correct_answer yalnızca A, B, C, D veya E olabilir.
- Her soruda tek bir doğru cevap üret.
- Doğru cevap, hesap veya kavramsal gerekçeyle savunulabilir olsun.
- JSON şeması tam olarak şu olsun:
{
  "questions": [
    {
      "question_text": "...",
      "option_a": "...",
      "option_b": "...",
      "option_c": "...",
      "option_d": "...",
      "option_e": "...",
      "correct_answer": "A",
      "difficulty": "${input.difficulty}"
    }
  ]
}`;
}

function buildStyleInstructions(questionStyle: QuestionStyle) {
  switch (questionStyle) {
    case "new_generation":
      return `- Yeni nesil soru üret.
- Soru kökü kısa bir işlem cümlesi gibi olmasın; anlamlı bir senaryo, veri, bağlam veya günlük yaşam durumu içersin.
- Öğrenci yalnızca formül hatırlayarak değil, veriyi yorumlayarak ve çok adımlı düşünerek sonuca ulaşsın.
- Çözüm için en az iki zihinsel adım gereksin.
- Gerekirse kısa metin, deney durumu, gözlem, tablo benzeri bağlam kullan.`;
    case "short_drill":
      return `- Hızlı tekrar sorusu üret ama ölçücü olsun.
- Kök kısa olabilir, ancak yüzeysel olmasın.
- Tek bilgi ezberi yerine kavramı doğru uygulamayı ölç.`;
    case "long_paragraph":
      return `- Daha uzun bağlamlı soru üret.
- Öğrencinin metinden veri ayıklamasını ve bağlamı çözmesini gerektir.`;
    case "table_interpretation":
      return `- Soruyu tablo verisi yorumlatacak şekilde kur.
- Tablodaki ilişkiyi anlamadan cevaplanamayacak bir yapı kullan.`;
    case "graph_interpretation":
      return `- Soruyu grafiksel veya değişim ilişkisi yorumlatacak biçimde kur.
- Eksen, eğilim, artış-azalış veya ilişki mantığı gereksin.`;
    case "standard":
    default:
      return `- Klasik soru üret ama basit olmasın.
- Soru kökü net, temiz ve öğretici olsun.
- Öğrenciyi zorlayacak güçlü çeldiriciler kullan.
- Klasik formatta olsa bile tek adım ezber sorusu üretme.`;
  }
}

function buildDifficultyInstructions(difficulty: Difficulty) {
  switch (difficulty) {
    case "easy":
      return `- Kolay düzeyde olsun ama çok yüzeysel olmasın.
- Temel kavramı doğru anlayan öğrenci çözebilsin.`;
    case "hard":
      return `- Zor düzeyde olsun.
- Güçlü çeldiriciler, çok adımlı düşünme ve kavram transferi içersin.
- Öğrenciyi gerçekten ayırt edecek düzeyde ölçücü olsun.`;
    case "medium":
    default:
      return `- Orta düzeyde olsun.
- Temel bilgiyi yorumla birleştiren dengeli bir zorluk kur.`;
  }
}

function buildTopicInstructionsV2(input: {
  examName: string;
  subjectName: string;
  topicName: string;
  questionStyle: QuestionStyle;
}) {
  const subject = input.subjectName.trim().toLocaleLowerCase("tr-TR");
  const topic = input.topicName.trim().toLocaleLowerCase("tr-TR");
  const isNewGeneration = input.questionStyle === "new_generation";

  if (subject.includes("türkçe") && topic.includes("sözcükte anlam")) {
    return `- Sorular kısa bir bağlam, paragraf veya birden fazla cümle içeren anlamlı bir metin üzerinden kurulmalı.
- Tek bir kelimenin cümle içindeki anlamını, mecaz-gerçek anlam ayrımını, bağlama göre kazandığı anlamı veya anlam kaymasını gerçekten ölçmeli.
- Soru kökü açık olmalı; öğrenciden tam olarak ne istendiği ilk okumada anlaşılmalı.
- Şıklar birbirine yakın ama ayırt edilebilir anlam seçenekleri sunmalı.
- Doğru cevap yalnızca bir tane olmalı.
- Soru metni tek cümlelik olmasın; öğrencinin bağlamdan anlam çıkaracağı kadar detaylı olsun.
${isNewGeneration ? "- Yeni nesilde bağlamı daha güçlü kur ve öğrencinin kelimenin anlamını sadece sözlük bilgisiyle değil, bağlam çözümlemesiyle bulmasını sağla." : "- Klasik stilde net ama güçlü bir anlam sorusu kur."}`;
  }

  if (subject.includes("türkçe")) {
    return `- Türkçe sorularında anlam, yorum, çıkarım ve bağlam çözümlemesi ön planda olsun.
- Kısa ve mekanik soru yerine güçlü soru kökü ve kaliteli çeldiriciler kullan.
${isNewGeneration ? "- Yeni nesilde kısa metin, durum veya parçadan sonuç çıkarma gerektiren yapı kur." : "- Klasik stilde açık ve öğretici soru kurgusu kullan."}`;
  }

  if (subject.includes("matematik") || subject.includes("geometri")) {
    return `- Sorular hesap, yorum veya kavramsal çözüm gerektirmeli.
- Doğru seçenek hesaplama veya matematiksel akıl yürütmeyle savunulabilir olmalı.
- Şıklar birbirine yakın ama ayırt edilebilir olsun.
${isNewGeneration ? "- Yeni nesilde problem bağlamı, günlük yaşam durumu veya çok adımlı yorum kullan." : "- Klasik stilde net verilenlerle çözülen ama güçlü çeldiricili soru üret."}`;
  }

  if (subject.includes("kimya") || subject.includes("fizik") || subject.includes("biyoloji")) {
    return `- Sorular hesap, yorum, gözlem veya kavramsal çözüm gerektirmeli.
- Doğru seçenek hesaplama ya da bilimsel çıkarımla savunulabilir olmalı.
- Belirsiz ve yoruma açık şık üretme.
${isNewGeneration ? "- Yeni nesilde deney düzeneği, gözlem, tablo, günlük yaşam bağlamı veya çok adımlı bilimsel yorum kullan." : "- Klasik stilde net kavram ve işlem ağırlıklı ama kaliteli soru üret."}`;
  }

  if (subject.includes("tarih") || subject.includes("coğrafya") || subject.includes("felsefe") || subject.includes("din")) {
    return `- Sorular salt ezber cümlesi olmasın; yorumlama, karşılaştırma ve neden-sonuç ilişkisi içersin.
- Şıklar bilgi bakımından yakın ama ayırt edilebilir olsun.
${isNewGeneration ? "- Yeni nesilde kısa metin, tablo, harita bilgisi veya durum analizi kullan." : "- Klasik stilde açık köklü, bilgi ve yorum dengeli soru kur."}`;
  }

  return `- Soru, ${input.subjectName} dersi ve ${input.topicName} konusu için gerçekten ölçücü olsun.
- Kısa ve yüzeysel soru yerine bağlamı güçlü, açık köklü ve 5 şıklı sorular üret.
- Öğrencinin ezber değil, anlama ve ayırt etme becerisini ölç.
${isNewGeneration ? "- Yeni nesilde çok adımlı düşünme ve yorumlama gerektir." : "- Klasik stilde net ama güçlü soru kökü kur."}`;
}

async function generateQuestionsWithGemini(input: {
  prompt: string;
  apiKey: string;
  model: string;
  baseUrl: string;
}): Promise<GeneratedQuestion[]> {
  const response = await fetch(
    `${input.baseUrl.replace(/\/$/, "")}/models/${input.model}:generateContent?key=${input.apiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: input.prompt }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          topP: 0.9,
          responseMimeType: "application/json",
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(
      `Gemini API hatası: ${response.status} ${await response.text()}`,
    );
  }

  const decoded = await response.json();
  const text = extractText(decoded);
  if (!text) {
    throw new Error("Gemini geçerli içerik döndürmedi.");
  }

  const parsed = parseJsonPayload(text);
  const questions = extractQuestionsFromPayload(parsed);

  if (questions.length === 0) {
    throw new Error(
      `Gemini soru üretemedi. Model çıktısı beklenen soru listesi formatında değil. Çıktı özeti: ${text.slice(0, 400)}`,
    );
  }

  return questions.map(validateQuestion);
}

function extractText(payload: Record<string, unknown>): string | null {
  const candidates = Array.isArray(payload.candidates) ? payload.candidates : [];
  if (candidates.length === 0) return null;

  const content = (candidates[0] as Record<string, unknown>).content as
    | Record<string, unknown>
    | undefined;
  const parts = Array.isArray(content?.parts) ? content.parts : [];
  const texts = parts
    .map((part) => (part as Record<string, unknown>).text)
    .filter(
      (value): value is string =>
        typeof value === "string" && value.trim().length > 0,
    );

  return texts.length === 0 ? null : texts.join("\n");
}

function parseJsonPayload(rawText: string) {
  const trimmed = rawText.trim();

  try {
    return JSON.parse(trimmed);
  } catch {
    const withoutCodeFence = trimmed
        .replace(/^```json\s*/i, "")
        .replace(/^```\s*/i, "")
        .replace(/\s*```$/i, "")
        .trim();

    try {
      return JSON.parse(withoutCodeFence);
    } catch {
      const start = withoutCodeFence.indexOf("{");
      const end = withoutCodeFence.lastIndexOf("}");
      if (start !== -1 && end !== -1 && end > start) {
        const sliced = withoutCodeFence.slice(start, end + 1);
        return JSON.parse(sliced);
      }
      throw new Error("Gemini geçerli JSON döndürmedi.");
    }
  }
}

function extractQuestionsFromPayload(parsed: unknown): Record<string, unknown>[] {
  if (Array.isArray(parsed)) {
    return parsed.filter(
      (item): item is Record<string, unknown> =>
          typeof item === "object" && item !== null,
    );
  }

  if (typeof parsed !== "object" || parsed === null) {
    return [];
  }

  const payload = parsed as Record<string, unknown>;

  if (Array.isArray(payload.questions)) {
    return payload.questions.filter(
      (item): item is Record<string, unknown> =>
          typeof item === "object" && item !== null,
    );
  }

  if (
    typeof payload.question_text === "string" &&
    typeof payload.option_a === "string" &&
    typeof payload.option_b === "string" &&
    typeof payload.option_c === "string" &&
    typeof payload.option_d === "string"
  ) {
    return [payload];
  }

  return [];
}

function validateQuestion(raw: Record<string, unknown>): GeneratedQuestion {
  const question = {
    question_text: requiredPlainText(raw.question_text, "question_text"),
    option_a: requiredOptionText(raw.option_a, "option_a"),
    option_b: requiredOptionText(raw.option_b, "option_b"),
    option_c: requiredOptionText(raw.option_c, "option_c"),
    option_d: requiredOptionText(raw.option_d, "option_d"),
    option_e: optionalOptionText(raw.option_e) ?? undefined,
    correct_answer: requiredAnswer(extractAnswerValue(raw)),
    difficulty: asDifficulty(raw.difficulty),
  } satisfies GeneratedQuestion;

  const usedOptions = [
    question.option_a,
    question.option_b,
    question.option_c,
    question.option_d,
    question.option_e ?? "",
  ].filter((item) => item.trim().length > 0);

  if (usedOptions.length < 4) {
    throw new Error("Soru en az 4 şık içermeli.");
  }

  if (question.question_text.trim().length < 60) {
    throw new Error("Soru kökü çok kısa. Daha detaylı ve bağlamlı olmalı.");
  }

  return question;
}

function buildOptions(questionId: string, question: GeneratedQuestion) {
  const options: Array<{ option_key: "A" | "B" | "C" | "D" | "E"; option_text: string }> = [
    { option_key: "A", option_text: question.option_a },
    { option_key: "B", option_text: question.option_b },
    { option_key: "C", option_text: question.option_c },
    { option_key: "D", option_text: question.option_d },
  ];

  if (question.option_e && question.option_e.trim().length > 0) {
    options.push({ option_key: "E", option_text: question.option_e });
  }

  return options.map((option) => ({
    question_id: questionId,
    option_key: option.option_key,
    option_text: option.option_text.trim(),
  }));
}

function normalizeStem(input: string) {
  return input
    .toLocaleLowerCase("tr-TR")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function requiredString(value: unknown, key: string) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${key} zorunlu.`);
  }
  return value.trim();
}

function requiredPlainText(value: unknown, key: string) {
  const text = requiredString(value, key);
  if (text.length < 6) {
    throw new Error(`${key} çok kısa.`);
  }
  return text;
}

function optionalPlainText(value: unknown) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length === 0 ? null : text;
}

function requiredOptionText(value: unknown, key: string) {
  const text = requiredString(value, key);
  if (text.length < 1) {
    throw new Error(`${key} çok kısa.`);
  }
  return text;
}

function optionalOptionText(value: unknown) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (text.length === 0) {
    return null;
  }
  return text.length < 1 ? null : text;
}

function requiredAnswer(value: unknown): GeneratedQuestion["correct_answer"] {
  if (typeof value !== "string") {
    throw new Error("correct_answer zorunlu.");
  }

  const normalized = value.trim().toUpperCase();
  if (["A", "B", "C", "D", "E"].includes(normalized)) {
    return normalized as GeneratedQuestion["correct_answer"];
  }

  const letterMatch = normalized.match(/\b([A-E])\b/);
  if (!letterMatch) {
    throw new Error("correct_answer geçersiz.");
  }

  return letterMatch[1] as GeneratedQuestion["correct_answer"];
}

function extractAnswerValue(raw: Record<string, unknown>) {
  return raw.correct_answer ??
      raw.correctAnswer ??
      raw.correct ??
      raw.answerLetter ??
      raw.correct_choice ??
      raw.answer ??
      raw.answer_key ??
      raw.correct_option ??
      raw.correctOption ??
      raw.dogru_cevap ??
      raw.dogruCevap ??
      raw.cevap;
}

function asDifficulty(value: unknown): Difficulty {
  const normalized = typeof value === "string"
    ? value.trim().toLowerCase()
    : "medium";
  if (normalized === "easy" || normalized === "medium" || normalized === "hard") {
    return normalized;
  }
  return "medium";
}

function asQuestionStyle(value: unknown): QuestionStyle {
  const normalized = typeof value === "string"
    ? value.trim().toLowerCase()
    : "standard";
  const allowed: QuestionStyle[] = [
    "standard",
    "new_generation",
    "short_drill",
    "long_paragraph",
    "table_interpretation",
    "graph_interpretation",
  ];
  return allowed.includes(normalized as QuestionStyle)
    ? (normalized as QuestionStyle)
    : "standard";
}

function asPositiveInt(value: unknown, min: number, max: number) {
  const numberValue = typeof value === "number"
    ? Math.round(value)
    : Number.parseInt(String(value ?? ""), 10);
  if (!Number.isFinite(numberValue) || numberValue < min || numberValue > max) {
    throw new Error(`Değer ${min} ile ${max} arasında olmalı.`);
  }
  return numberValue;
}

function mustEnv(key: string) {
  const value = Deno.env.get(key);
  if (!value) {
    throw new Error(`${key} tanımlı değil.`);
  }
  return value;
}

function normalizeGoogleApiBaseUrl(baseUrl: string) {
  const trimmed = baseUrl.trim().replace(/\/$/, "");
  if (trimmed.endsWith("/v1")) {
    return `${trimmed}beta`;
  }
  return trimmed;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
